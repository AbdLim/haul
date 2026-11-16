import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'file_writer.dart';
import 'models/download_error.dart';
import 'models/download_request.dart';
import 'models/segment.dart';
import 'network_settings.dart';
import 'request_headers.dart';

/// The live, mutable state of one segment. The task owns these and turns
/// them into immutable [Segment]s for snapshots. [end] can be lowered
/// while a worker is running (see `splitLargest`), and the worker notices.
class SegmentState {
  SegmentState({
    required this.id,
    required this.start,
    required this.end,
    this.downloaded = 0,
    this.status = SegmentStatus.pending,
  });

  factory SegmentState.from(Segment s) => SegmentState(
    id: s.id,
    start: s.start,
    end: s.end,
    downloaded: s.downloaded,
    status: s.status,
  );

  final int id;
  final int start;
  int end;
  int downloaded;
  SegmentStatus status;

  int get length => end - start + 1;
  int get nextByte => start + downloaded;
  int get remaining => length - downloaded;
  bool get isComplete => nextByte > end;

  Segment toSegment() => Segment(
    id: id,
    start: start,
    end: end,
    downloaded: min(downloaded, length),
    status: status,
  );
}

/// Downloads one segment over one connection, writing through [writer].
///
/// A worker makes a single attempt. It returns normally when the segment is
/// finished or the worker was cancelled, and throws [DownloadError]
/// otherwise; retrying is the caller's job.
class SegmentWorker {
  SegmentWorker({
    required this.client,
    required this.request,
    required this.url,
    required this.segment,
    required this.writer,
    this.etag,
    this.lastModified,
    this.onBytes,
    this.throttle,
    this.stallTimeout = const Duration(seconds: 30),
    this.network,
  });

  final HttpClient client;
  final DownloadRequest request;
  final Uri url;
  final SegmentState segment;
  final FileWriter writer;

  /// Validators for `If-Range`.
  final String? etag;
  final String? lastModified;

  /// Called with the size of each chunk after it has been written.
  final void Function(int bytes)? onBytes;

  /// Called before each chunk is written; the worker waits for it. Used by
  /// the speed limiter.
  final Future<void> Function(int bytes)? throttle;
  final Duration stallTimeout;

  /// Read for every request, so a login added later applies at once.
  final NetworkSettings? network;

  HttpClientRequest? _http;
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  /// Stops the transfer. [run] then returns without error.
  void cancel() {
    _cancelled = true;
    _http?.abort();
  }

  String? get _ifRange {
    final tag = etag;
    // Weak validators are not allowed in If-Range.
    if (tag != null && !tag.startsWith('W/')) return tag;
    return lastModified;
  }

  Future<void> run() async {
    if (segment.isComplete || _cancelled) return;
    final from = segment.nextByte;
    final ifRange = _ifRange;

    try {
      final http = await client.getUrl(url);
      _http = http;
      http.followRedirects = true;
      http.maxRedirects = 10;
      applyRequestHeaders(http, request, network: network?.config);
      http.headers.set(HttpHeaders.rangeHeader, 'bytes=$from-${segment.end}');
      if (ifRange != null) http.headers.set(HttpHeaders.ifRangeHeader, ifRange);

      final response = await http.close().timeout(
        stallTimeout,
        onTimeout: () {
          http.abort();
          throw const DownloadError(
            DownloadErrorCode.network,
            'The server did not answer',
            retryable: true,
          );
        },
      );
      if (_cancelled) return;
      _checkResponse(response, from, sentIfRange: ifRange != null);

      final stream = response.timeout(
        stallTimeout,
        onTimeout: (sink) {
          sink.addError(
            const DownloadError(
              DownloadErrorCode.network,
              'The connection stalled',
              retryable: true,
            ),
          );
          sink.close();
        },
      );

      await for (final chunk in stream) {
        if (_cancelled) return;
        // The end can move after a split, so look every time.
        final room = segment.end - segment.nextByte + 1;
        if (room <= 0) return;
        final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
        final take = min(bytes.length, room);
        final data = take == bytes.length
            ? bytes
            : Uint8List.sublistView(bytes, 0, take);

        await throttle?.call(data.length);
        if (_cancelled) return;
        await writer.write(segment.nextByte, data);
        // The end may have been lowered while this write was in flight.
        // Bytes past it are duplicates of what the new segment fetches, so
        // they must not count toward this segment.
        segment.downloaded = min(
          segment.downloaded + data.length,
          segment.length,
        );
        onBytes?.call(data.length);

        // Leaving the loop cancels the subscription, which drops the
        // connection even if the server still has more to send.
        if (segment.isComplete) return;
      }

      if (!segment.isComplete && !_cancelled) {
        throw const DownloadError(
          DownloadErrorCode.network,
          'The connection closed early',
          retryable: true,
        );
      }
    } on SocketException catch (e) {
      if (_cancelled) return;
      // ECONNREFUSED is 61 on macOS and 111 on Linux.
      final code = e.osError?.errorCode;
      throw DownloadError(
        DownloadErrorCode.network,
        e.message,
        retryable: true,
        overload: code == 61 || code == 111,
      );
    } on TlsException catch (e) {
      throw DownloadError(DownloadErrorCode.network, 'TLS error: ${e.message}');
    } on HttpException catch (e) {
      if (_cancelled) return;
      throw DownloadError(
        DownloadErrorCode.network,
        e.message,
        retryable: true,
      );
    } finally {
      _http = null;
    }
  }

  bool _sameValidator(HttpClientResponse response) {
    final tag = etag;
    if (tag != null && !tag.startsWith('W/')) {
      return firstHeader(response.headers, HttpHeaders.etagHeader) == tag;
    }
    return firstHeader(response.headers, HttpHeaders.lastModifiedHeader) ==
        lastModified;
  }

  void _checkResponse(
    HttpClientResponse response,
    int from, {
    required bool sentIfRange,
  }) {
    final code = response.statusCode;
    switch (code) {
      case 206:
        break;
      case 200:
        // The server sent the whole file instead of our range. If it
        // still carries the validator we sent, it simply ignores ranges;
        // if the validator differs, the file really changed.
        if (sentIfRange && !_sameValidator(response)) {
          throw const DownloadError(
            DownloadErrorCode.fileChanged,
            'The file changed on the server',
          );
        }
        throw const DownloadError(
          DownloadErrorCode.rangeIgnored,
          'The server ignored the byte range',
        );
      case 401:
        throw const DownloadError(
          DownloadErrorCode.authRequired,
          'This site needs a login',
        );
      case 403:
        throw const DownloadError(
          DownloadErrorCode.forbidden,
          'The server refused access',
        );
      case 404:
        throw const DownloadError(DownloadErrorCode.notFound, 'File not found');
      case 407:
        throw const DownloadError(
          DownloadErrorCode.proxyAuth,
          'The proxy needs a login',
        );
      case 410:
        throw const DownloadError(
          DownloadErrorCode.gone,
          'The link has expired',
        );
      default:
        if (code == 408 || code == 429 || code >= 500) {
          throw DownloadError(
            DownloadErrorCode.server,
            'Server responded with $code',
            retryable: true,
            overload: code == 429 || code == 503,
          );
        }
        throw DownloadError(
          DownloadErrorCode.unknown,
          'Unexpected response $code',
        );
    }

    // The range we got must start where we asked.
    final header = firstHeader(
      response.headers,
      HttpHeaders.contentRangeHeader,
    );
    final m = header == null
        ? null
        : RegExp(r'bytes\s+(\d+)-').firstMatch(header);
    if (m == null || int.parse(m.group(1)!) != from) {
      throw DownloadError(
        DownloadErrorCode.rangeIgnored,
        'The server answered with the wrong byte range ($header)',
      );
    }
  }
}
