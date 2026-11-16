import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// One request as seen by the server.
class RequestLogEntry {
  RequestLogEntry({
    required this.method,
    required this.path,
    required this.headers,
    required this.at,
  });

  final String method;
  final String path;
  final Map<String, String> headers;
  final DateTime at;
  int status = 0;

  /// Bytes actually written to the client for this request.
  int bytesSent = 0;

  String? get range => headers['range'];

  /// First byte requested, or 0 when there was no usable Range header.
  int get rangeStart {
    final m = RegExp(r'bytes=(\d+)-').firstMatch(range ?? '');
    return m == null ? 0 : int.parse(m.group(1)!);
  }
}

/// A local HTTP server for engine tests. Serves deterministic pseudo-random
/// bytes of a chosen size and can misbehave on demand.
class RangeServer {
  RangeServer._(this._server, this.size);

  final HttpServer _server;
  final int size;

  /// Behaviour switches. All can be changed while the server runs.
  bool noRanges = false;
  int? throttleBytesPerSec;

  /// If set, a response whose range starts at [slowRangeStart] uses this
  /// rate instead, to model one slow connection among fast ones.
  int? slowRangeStart;
  int? slowBytesPerSec;
  int? dropAfterBytes;

  /// For the next [_stallResponses] responses, go silent (connection open)
  /// after sending this many bytes.
  int stallAfterBytes = 0;
  int stallResponses = 0;
  int? maxConnections;
  String? contentDisposition;

  /// Honour the probe's `bytes=0-0` but ignore every other Range header.
  bool ignoreRangeAfterProbe = false;

  /// Answer ranged requests with `Content-Range: bytes a-b/*`.
  bool unknownTotal = false;
  String? basicAuthUser;
  String? basicAuthPassword;

  /// If set, every request except a probe (`bytes=0-0`) answers with this
  /// status and no body.
  int? failAfterProbe;

  /// If set, every request answers with this status and no body.
  int? forceStatus;

  final List<RequestLogEntry> log = [];
  int _active = 0;
  int peakConcurrent = 0;

  /// Requests being handled right now.
  int get activeNow => _active;

  /// Most requests being served at once, not counting rejected ones.
  int peakServed = 0;
  int _served = 0;
  int rejected = 0;

  /// Status used when [maxConnections] is exceeded.
  int rejectStatus = 503;

  /// Answer this many non-probe requests with 503, then behave.
  int failAfterProbeCount = 0;

  /// Once this many bytes have been served in total, every non-probe
  /// request answers [statusAfterBytesCode]. Models an expiring link.
  int? statusAfterBytes;
  int statusAfterBytesCode = 403;
  int _totalServed = 0;
  int _failCount = 0;
  int _failStatus = 503;
  int _etagVersion = 1;
  final Map<String, String> _redirects = {};

  static Future<RangeServer> start({
    required int size,
    bool noRanges = false,
    int? throttleBytesPerSec,
    int? dropAfterBytes,
    int? maxConnections,
    String? contentDisposition,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final s = RangeServer._(server, size)
      ..noRanges = noRanges
      ..throttleBytesPerSec = throttleBytesPerSec
      ..dropAfterBytes = dropAfterBytes
      ..maxConnections = maxConnections
      ..contentDisposition = contentDisposition;
    server.listen(s._handle);
    return s;
  }

  int get port => _server.port;
  Uri get url => Uri.parse('http://127.0.0.1:$port/file.bin');
  Uri urlFor(String path) => Uri.parse('http://127.0.0.1:$port$path');

  /// The current ETag, which changes after [changeEtag].
  String get etag => '"v$_etagVersion"';

  /// Answer the next [n] requests with [status] (default 503).
  void failNextRequests(int n, [int status = 503]) {
    _failCount = n;
    _failStatus = status;
  }

  /// Makes the server look like a different file to anyone holding the
  /// old validator.
  void changeEtag() => _etagVersion++;

  /// Requests to [path] get a 302 to the real file.
  Uri redirectFrom(String path) {
    _redirects[path] = '/file.bin';
    return urlFor(path);
  }

  /// Requests to [path] get a 302 to the same file under another host name
  /// (for example `127.0.0.1` versus `localhost`).
  Uri redirectToHost(String path, String host) {
    _redirects[path] = 'http://$host:$port/file.bin';
    return urlFor(path);
  }

  int _seed = 0;

  /// Deterministic content: byte at [offset].
  int byteAt(int offset) =>
      ((offset * 2654435761) >> 11 ^ offset ^ _seed) & 0xff;

  /// Serves different bytes from now on, with a new ETag.
  void changeContent() {
    _seed += 0x5a;
    changeEtag();
  }

  /// The expected bytes in [start, end] inclusive.
  Uint8List bytes(int start, int end) {
    final out = Uint8List(end - start + 1);
    for (var i = 0; i < out.length; i++) {
      out[i] = byteAt(start + i);
    }
    return out;
  }

  Uint8List get allBytes => bytes(0, size - 1);

  final _shutdown = Completer<void>();

  Future<void> close() {
    if (!_shutdown.isCompleted) _shutdown.complete();
    return _server.close(force: true);
  }

  // -- request handling ----------------------------------------------------

  Future<void> _handle(HttpRequest req) async {
    final headers = <String, String>{};
    req.headers.forEach((name, values) => headers[name] = values.join(', '));
    final entry = RequestLogEntry(
      method: req.method,
      path: req.uri.path,
      headers: headers,
      at: DateTime.now(),
    );
    log.add(entry);
    final res = req.response;

    Future<void> finish(int status) async {
      entry.status = status;
      res.statusCode = status;
      await res.close();
    }

    final redirect = _redirects[req.uri.path];
    if (redirect != null) {
      res.headers.set(HttpHeaders.locationHeader, redirect);
      return finish(302);
    }
    if (forceStatus != null) return finish(forceStatus!);
    if (failAfterProbe != null && entry.range != 'bytes=0-0') {
      return finish(failAfterProbe!);
    }
    if (statusAfterBytes != null &&
        _totalServed >= statusAfterBytes! &&
        entry.range != 'bytes=0-0') {
      return finish(statusAfterBytesCode);
    }
    if (failAfterProbeCount > 0 && entry.range != 'bytes=0-0') {
      failAfterProbeCount--;
      return finish(503);
    }
    if (_failCount > 0) {
      _failCount--;
      return finish(_failStatus);
    }
    if (basicAuthUser != null) {
      final auth = req.headers.value(HttpHeaders.authorizationHeader);
      final expected = 'Basic ${_b64('$basicAuthUser:$basicAuthPassword')}';
      if (auth != expected) {
        res.headers.set(HttpHeaders.wwwAuthenticateHeader, 'Basic realm="t"');
        return finish(401);
      }
    }
    if (req.uri.path != '/file.bin') return finish(404);

    _active++;
    if (_active > peakConcurrent) peakConcurrent = _active;
    var counted = false;
    var released = false;
    // The slot is given back as soon as the last byte has been written, so
    // a client that finishes a range and immediately reconnects is never
    // counted as a second concurrent connection.
    void release() {
      if (released) return;
      released = true;
      _active--;
      if (counted) _served--;
    }

    try {
      if (maxConnections != null && _active > maxConnections!) {
        rejected++;
        return await finish(rejectStatus);
      }
      counted = true;
      _served++;
      if (_served > peakServed) peakServed = _served;
      await _serve(req, entry, release);
    } finally {
      release();
    }
  }

  Future<void> _serve(
    HttpRequest req,
    RequestLogEntry entry,
    void Function() release,
  ) async {
    final res = req.response;
    // A client that hangs up frees its slot even if this handler is stuck
    // waiting on a socket that will never drain.
    unawaited(res.done.then((_) => release(), onError: (_) => release()));
    var start = 0;
    var end = size - 1;
    var status = 200;

    final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
    final ifRange = req.headers.value(HttpHeaders.ifRangeHeader);
    final rangeUsable =
        !noRanges &&
        (ifRange == null || ifRange == etag) &&
        !(ignoreRangeAfterProbe && rangeHeader != 'bytes=0-0');
    final m = rangeHeader == null
        ? null
        : RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);

    if (rangeUsable && m != null) {
      start = int.parse(m.group(1)!);
      if (m.group(2)!.isNotEmpty) {
        end = min(int.parse(m.group(2)!), size - 1);
      }
      if (start >= size || start > end) {
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$size');
        entry.status = 416;
        res.statusCode = 416;
        await res.close();
        return;
      }
      status = 206;
      res.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/${unknownTotal ? '*' : size}',
      );
    }

    entry.status = status;
    res.statusCode = status;
    if (!noRanges) res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    res.headers.set(HttpHeaders.etagHeader, etag);
    res.headers.set(
      HttpHeaders.lastModifiedHeader,
      'Wed, 01 Jan 2025 00:00:00 GMT',
    );
    res.headers.contentType = ContentType.binary;
    final cd = contentDisposition;
    if (cd != null) res.headers.set('content-disposition', cd);
    res.contentLength = end - start + 1;

    if (req.method == 'HEAD') {
      await res.close();
      return;
    }

    const chunk = 16 * 1024;
    final limit = dropAfterBytes;
    final rate = (slowRangeStart == start && slowBytesPerSec != null)
        ? slowBytesPerSec
        : throttleBytesPerSec;
    final clock = Stopwatch()..start();
    // To cut a connection mid-body we need the raw socket. Detaching writes
    // the headers (with our Content-Length) and hands it over.
    final raw = limit != null ? await res.detachSocket() : null;
    final stallAt = stallResponses > 0 && entry.range != 'bytes=0-0'
        ? stallAfterBytes
        : null;
    if (stallAt != null) stallResponses--;
    var sent = 0;
    try {
      for (var o = start; o <= end; o += chunk) {
        var stop = (o + chunk - 1).clamp(0, end);
        if (limit != null && sent + (stop - o + 1) > limit) {
          stop = o + (limit - sent) - 1;
        }
        if (stallAt != null && sent >= stallAt) {
          await res.flush();
          // Hold the connection open and send nothing until the client
          // gives up or the server shuts down.
          await _shutdown.future;
          return;
        }
        if (stop >= o) {
          final data = bytes(o, stop);
          raw != null ? raw.add(data) : res.add(data);
          if (stop >= end) release();
          sent += stop - o + 1;
          _totalServed += stop - o + 1;
          entry.bytesSent = sent;
        }
        if (raw != null && limit != null && sent >= limit && stop < end) {
          await raw.flush();
          raw.destroy();
          return;
        }
        if (rate != null) {
          // Sleep until the wall clock catches up with the allowed rate.
          final due = Duration(microseconds: sent * 1000000 ~/ rate);
          final wait = due - clock.elapsed;
          raw != null ? await raw.flush() : await res.flush();
          if (wait > Duration.zero) await Future<void>.delayed(wait);
        }
      }
      if (raw != null) {
        await raw.flush();
        await raw.close();
      } else {
        await res.close();
      }
    } on Object catch (e) {
      // The client went away (pause, cancel, split). Nothing to clean up.
      if (Platform.environment['RANGE_SERVER_DEBUG'] != null) stderr.writeln(e);
    }
  }

  static String _b64(String s) => base64.encode(utf8.encode(s));
}
