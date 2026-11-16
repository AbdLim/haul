import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'file_writer.dart';
import 'filename.dart';
import 'models/download_error.dart';
import 'models/download_snapshot.dart';
import 'models/download_status.dart';
import 'models/events.dart';
import 'models/segment.dart';
import 'network_settings.dart';
import 'probe.dart';
import 'rate_limiter.dart';
import 'request_headers.dart';
import 'segment_planner.dart';
import 'segment_worker.dart';
import 'speed_meter.dart';

/// Waits before retry number 1, 2, 3, ... The last value repeats.
const defaultRetryDelays = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 16),
  Duration(seconds: 30),
];

Future<void> _realSleep(Duration d) => Future<void>.delayed(d);

/// Runs one download from probe to the finished file.
///
/// Create it with a snapshot (a fresh one for a new download), call [run],
/// and listen to [events]. [run] never throws: the outcome is the last
/// snapshot, whose status is `completed` or `failed`.
class DownloadTask {
  DownloadTask({
    required DownloadSnapshot snapshot,
    required HttpClient client,
    this.stallTimeout = const Duration(seconds: 30),
    this.progressInterval = const Duration(milliseconds: 250),
    this.checkpointInterval = const Duration(seconds: 1),
    Duration speedWindow = const Duration(seconds: 5),
    this.retryDelays = defaultRetryDelays,
    this.maxFailures = 8,
    this.sleep = _realSleep,
    this.limiter,
    this.network,
  }) : _snapshot = snapshot,
       _client = client,
       _meter = SpeedMeter(window: speedWindow);

  final HttpClient _client;
  final Duration stallTimeout;

  /// Backoff schedule and the number of failures in a row after which a
  /// segment (or the probe) gives up. Injectable so tests run fast.
  final List<Duration> retryDelays;
  final int maxFailures;
  final Future<void> Function(Duration) sleep;

  /// Shared speed limit, or null for none.
  final RateLimiter? limiter;

  /// Proxy-independent network settings: site logins and so on.
  final NetworkSettings? network;
  var _stopSignal = Completer<void>();

  /// Progress events are sent at most once per interval (four per second).
  final Duration progressInterval;
  final SpeedMeter _meter;
  Timer? _progressTimer;

  /// While downloading, a full snapshot is emitted this often so the app can
  /// persist progress. Null turns it off.
  final Duration? checkpointInterval;
  Timer? _checkpointTimer;
  bool _checkpointing = false;

  DownloadSnapshot _snapshot;
  final _events = StreamController<EngineEvent>.broadcast();
  final _states = <SegmentState>[];
  final _workers = <SegmentWorker>[];
  FileWriter? _writer;
  bool _stopping = false;
  bool _pauseRequested = false;

  /// How many connections may run at once. Starts at the request's limit
  /// and drops by one each time the server pushes back (429, 503, refused).
  int _connectionLimit = 0;
  int _runningLoops = 0;
  HttpClientRequest? _singleRequest;
  HttpClientRequest? _probeRequest;
  final _finished = Completer<void>();

  DownloadSnapshot get snapshot => _snapshot;
  Stream<EngineEvent> get events => _events.stream;

  /// Runs to completion or failure.
  Future<DownloadSnapshot> run() async {
    try {
      _setStatus(DownloadStatus.probing, clearError: true);
      if (_canResume) {
        await _resumeSetup();
      } else {
        await _prepare();
      }
      if (_pauseRequested) return await _finishPaused();
      _setStatus(DownloadStatus.downloading);
      _progressTimer = Timer.periodic(progressInterval, (_) => _emitProgress());
      final every = checkpointInterval;
      if (every != null) {
        _checkpointTimer = Timer.periodic(every, (_) => _checkpoint());
      }

      await _transfer();
      if (_pauseRequested) return await _finishPaused();
      await _finish();
      _setStatus(DownloadStatus.completed);
    } on DownloadError catch (e) {
      await _writer?.close();
      // A link that worked and then stopped (403, 410) has most likely
      // expired. The data so far is good, so wait for a fresh link.
      final expired =
          (e.code == DownloadErrorCode.forbidden ||
              e.code == DownloadErrorCode.gone) &&
          _states.any((s) => s.downloaded > 0) &&
          _snapshot.supportsRanges;
      _snapshot = _snapshot.copyWith(
        status: expired ? DownloadStatus.needsRefresh : DownloadStatus.failed,
        error: e,
        segments: _currentSegments(),
      );
      _emitSnapshot();
    } on FileSystemException catch (e) {
      await _writer?.close();
      _snapshot = _snapshot.copyWith(
        status: DownloadStatus.failed,
        error: DownloadError(
          DownloadErrorCode.unknown,
          'File error: ${e.osError?.message ?? e.message}',
        ),
        segments: _currentSegments(),
      );
      _emitSnapshot();
    } finally {
      _progressTimer?.cancel();
      _checkpointTimer?.cancel();
      await _events.close();
      if (!_finished.isCompleted) _finished.complete();
    }
    return _snapshot;
  }

  /// Moves the bytes. Handles the two ways a server can surprise us
  /// mid-download: it ignores ranges (go single-connection) or the file
  /// changed under us (start again from zero).
  Future<void> _transfer() async {
    var restarts = 0;
    while (true) {
      try {
        if (_snapshot.supportsRanges) {
          await _downloadSegmented();
        } else {
          await _downloadSingle();
        }
        return;
      } on DownloadError catch (e) {
        if (_pauseRequested) return;
        if (e.code == DownloadErrorCode.rangeIgnored &&
            _snapshot.supportsRanges) {
          await _restartAsSingle();
          continue;
        }
        if (e.code == DownloadErrorCode.fileChanged && restarts++ < 2) {
          await _restartFromZero();
          if (_pauseRequested) return;
          continue;
        }
        rethrow;
      }
    }
  }

  /// The server's file is not the one we were downloading. Throw away the
  /// partial data, tell the app, and begin again with fresh metadata.
  Future<void> _restartFromZero() async {
    _events.add(FileChangedEvent(_snapshot.id));
    await _writer?.close();
    final part = File(_snapshot.partPath!);
    if (part.existsSync()) part.deleteSync();
    _stopping = false;
    _stopSignal = Completer<void>();
    _meter.reset();
    _snapshot = _snapshot.copyWith(
      status: DownloadStatus.probing,
      segments: const [],
    );
    _emitSnapshot();
    await _prepare();
    _setStatus(DownloadStatus.downloading);
  }

  // -- pause and resume ----------------------------------------------------

  /// Stops all transfers, flushes the file and ends [run] with a `paused`
  /// snapshot. Completes once that snapshot has been emitted.
  Future<void> pause() {
    if (_finished.isCompleted) return Future.value();
    _pauseRequested = true;
    _stopWorkers();
    _singleRequest?.abort();
    // Drop a connection that is still waiting for the server to answer.
    _probeRequest?.abort();
    return _finished.future;
  }

  bool get _canResume =>
      _snapshot.fileName != null && _snapshot.segments.isNotEmpty;

  /// Continues from a stored snapshot if the `.part` file is still intact,
  /// otherwise starts the data over (same URL, same file name).
  Future<void> _resumeSetup() async {
    final part = File(_snapshot.partPath!);
    final total = _snapshot.totalBytes;
    final intact =
        _snapshot.resumable &&
        part.existsSync() &&
        (total == null || part.lengthSync() == total);

    if (intact) {
      final segments = [
        for (final s in _snapshot.segments)
          // Whatever was in flight when we stopped is simply pending again.
          s.copyWith(
            status: s.downloaded >= s.length
                ? SegmentStatus.done
                : SegmentStatus.pending,
          ),
      ];
      _states
        ..clear()
        ..addAll(segments.map(SegmentState.from));
      _writer = await FileWriter.open(part.path);
      return;
    }

    // Missing, wrong size, or a single-connection download: begin again.
    final fresh = total != null && total > 0 && _snapshot.supportsRanges
        ? planSegments(total, _effectiveConnections)
        : [Segment(id: 0, start: 0, end: (total ?? 0) - 1)];
    _states
      ..clear()
      ..addAll(fresh.map(SegmentState.from));
    _writer = await FileWriter.create(part.path, total ?? 0);
  }

  Future<DownloadSnapshot> _finishPaused() async {
    await _writer?.close();
    _snapshot = _snapshot.copyWith(
      status: DownloadStatus.paused,
      segments: _currentSegments(),
    );
    _emitSnapshot();
    return _snapshot;
  }

  // -- setup ---------------------------------------------------------------

  /// The connection count this download may use: its own setting, or the
  /// site's cap if that is lower.
  int get _effectiveConnections {
    final own = _snapshot.request.maxConnections;
    final cap =
        network?.config.siteLimits[_snapshot.request.url.host.toLowerCase()];
    if (cap == null || cap < 1) return own;
    return cap < own ? cap : own;
  }

  /// Waits out the backoff for failure number [failures], or until the
  /// task is told to stop.
  Future<void> _backoff(int failures) {
    final i = failures - 1 < retryDelays.length
        ? failures - 1
        : retryDelays.length - 1;
    return Future.any([sleep(retryDelays[i]), _stopSignal.future]);
  }

  /// Null when a pause or cancel arrived first: the answer is no longer
  /// wanted, so the wait ends at once instead of when the server replies.
  Future<ProbeResult?> _probeWithRetry() async {
    var failures = 0;
    while (true) {
      if (_pauseRequested) return null;
      try {
        final attempt = probe(
          _snapshot.request,
          client: _client,
          network: network?.config,
          timeout: stallTimeout,
          onRequest: (r) => _probeRequest = r,
        );
        // If the stop wins, the abandoned probe's own timeout frees its
        // socket; its error must not escape.
        attempt.ignore();
        final result = await Future.any<ProbeResult?>([
          attempt,
          _stopSignal.future.then((_) => null),
        ]);
        return result;
      } on DownloadError catch (e) {
        if (_pauseRequested) return null;
        if (!e.retryable) rethrow;
        if (++failures >= maxFailures) {
          throw DownloadError(
            e.code,
            '${e.message} (gave up after $failures tries)',
          );
        }
        await _backoff(failures);
      }
    }
  }

  Future<void> _prepare() async {
    final request = _snapshot.request;
    final result = await _probeWithRetry();
    if (result == null) return; // paused or cancelled while connecting

    final saveDir = request.saveDir;
    await Directory(saveDir).create(recursive: true);
    final name = uniqueFileName(
      saveDir,
      resolveFileName(
        finalUrl: result.finalUrl,
        requested: request.fileName,
        contentDisposition: result.contentDisposition,
      ),
    );

    final total = result.totalBytes;
    final ranged = result.supportsRanges && total != null && total > 0;
    final planned = ranged
        ? planSegments(total, _effectiveConnections)
        : [Segment(id: 0, start: 0, end: (total ?? 0) - 1)];

    _snapshot = _snapshot.copyWith(
      finalUrl: result.finalUrl,
      fileName: name,
      totalBytes: total,
      supportsRanges: ranged,
      resumable: ranged,
      etag: result.etag,
      lastModified: result.lastModified,
      contentType: result.contentType,
      segments: planned,
    );
    _states
      ..clear()
      ..addAll(planned.map(SegmentState.from));

    _writer = await FileWriter.create(_snapshot.partPath!, total ?? 0);
  }

  Future<void> _restartAsSingle() async {
    _stopping = false;
    _stopSignal = Completer<void>();
    final total = _snapshot.totalBytes;
    final single = [Segment(id: 0, start: 0, end: (total ?? 0) - 1)];
    _snapshot = _snapshot.copyWith(
      supportsRanges: false,
      resumable: false,
      segments: single,
    );
    _states
      ..clear()
      ..addAll(single.map(SegmentState.from));
    await _writer?.close();
    _writer = await FileWriter.create(_snapshot.partPath!, total ?? 0);
  }

  // -- segmented transfer --------------------------------------------------

  Future<void> _downloadSegmented() async {
    // A round of workers can end with a segment still waiting: a retiring
    // connection hands its segment back just after the last other worker
    // looked for work and left. So go round again until nothing is left.
    while (!_stopping && _states.any((s) => !s.isComplete)) {
      final waiting = _states.where((s) => !s.isComplete).length;
      if (_connectionLimit == 0) {
        _connectionLimit = _effectiveConnections;
      }
      final slots = waiting < _connectionLimit ? waiting : _connectionLimit;
      _runningLoops = slots;
      final loops = [for (var i = 0; i < slots; i++) _workerLoop()];

      try {
        await Future.wait(loops, eagerError: true);
      } on Object {
        // First failure stops everyone else; the .part file stays.
        _stopWorkers();
        await Future.wait(
          loops.map((l) => l.then<void>((_) {}, onError: (_) {})),
        );
        rethrow;
      }
    }
  }

  /// One connection's life: keep taking segments until none are left.
  Future<void> _workerLoop() async {
    try {
      while (!_stopping) {
        var segment = _takePending();
        if (segment == null) {
          // Nothing waiting: help the slowest active segment instead.
          segment = _splitForFreeWorker();
          if (segment == null) return;
        }
        segment.status = SegmentStatus.active;
        final retire = await _runSegment(segment);
        if (segment.isComplete) {
          segment.status = SegmentStatus.done;
        } else if (!_stopping) {
          segment.status = SegmentStatus.pending;
        }
        if (retire) return;
      }
    } finally {
      _runningLoops--;
    }
  }

  /// Runs [segment] to the end, retrying temporary failures with backoff.
  /// The failure count resets whenever a retry brought new bytes.
  ///
  /// Returns true when this connection should retire because the server
  /// is limiting connections and the limit has been lowered below the
  /// number running.
  Future<bool> _runSegment(SegmentState segment) async {
    var failures = 0;
    while (!_stopping && !segment.isComplete) {
      final before = segment.downloaded;
      final worker = SegmentWorker(
        client: _client,
        request: _snapshot.request,
        url: _snapshot.request.url,
        segment: segment,
        writer: _writer!,
        etag: _snapshot.etag,
        lastModified: _snapshot.lastModified,
        stallTimeout: stallTimeout,
        onBytes: _meter.add,
        throttle: limiter?.acquire,
        network: network,
      );
      _workers.add(worker);
      try {
        await worker.run();
        return false;
      } on DownloadError catch (e) {
        if (_stopping) return false;
        if (!e.retryable) rethrow;
        if (e.overload && _runningLoops > 1) {
          // Other connections are working, so the server is simply
          // refusing this many. Use one fewer and hand the segment back.
          // Count down from what is actually running, not from the cap.
          if (_connectionLimit > _runningLoops) {
            _connectionLimit = _runningLoops;
          }
          if (_connectionLimit > 1) _connectionLimit--;
          if (_runningLoops > _connectionLimit) return true;
        }
        if (segment.downloaded > before) failures = 0;
        if (++failures >= maxFailures) {
          throw DownloadError(
            e.code,
            '${e.message} (gave up after $failures tries)',
          );
        }
      } finally {
        _workers.remove(worker);
      }
      await _backoff(failures);
    }
    return false;
  }

  /// Dynamic splitting. Runs synchronously, so no worker can observe a
  /// half-updated list.
  SegmentState? _splitForFreeWorker() {
    final result = splitLargest([for (final s in _states) s.toSegment()]);
    if (result == null) return null;
    for (final updated in result.segments) {
      if (updated.id == result.created.id) continue;
      // Lowering `end` is how the victim's worker learns to stop early.
      _states.firstWhere((s) => s.id == updated.id).end = updated.end;
    }
    final created = SegmentState.from(result.created);
    _states.add(created);
    return created;
  }

  SegmentState? _takePending() {
    for (final s in _states) {
      if (s.status == SegmentStatus.pending && !s.isComplete) return s;
    }
    return null;
  }

  void _stopWorkers() {
    _stopping = true;
    if (!_stopSignal.isCompleted) _stopSignal.complete();
    for (final w in _workers.toList()) {
      w.cancel();
    }
  }

  // -- single-connection transfer -----------------------------------------

  Future<void> _downloadSingle() async {
    var failures = 0;
    final state = _states.first;
    while (true) {
      try {
        await _singleAttempt();
        return;
      } on DownloadError catch (e) {
        if (!e.retryable || _pauseRequested) rethrow;
        // Without ranges every retry starts from zero.
        if (state.downloaded > 0) failures = 0;
        if (++failures >= maxFailures) {
          throw DownloadError(
            e.code,
            '${e.message} (gave up after $failures tries)',
          );
        }
        state
          ..downloaded = 0
          ..end = (_snapshot.totalBytes ?? 0) - 1;
        _meter.reset();
        await _backoff(failures);
        if (_pauseRequested) return;
      }
    }
  }

  Future<void> _singleAttempt() async {
    final request = _snapshot.request;
    final state = _states.first;
    state.status = SegmentStatus.active;
    final http = await _client.getUrl(request.url);
    _singleRequest = http;
    http.followRedirects = true;
    http.maxRedirects = 10;
    applyRequestHeaders(http, request, network: network?.config);

    try {
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
      if (response.statusCode != 200) {
        throw DownloadError(
          response.statusCode == 404
              ? DownloadErrorCode.notFound
              : DownloadErrorCode.server,
          'Server responded with ${response.statusCode}',
          retryable: response.statusCode >= 500,
        );
      }
      var offset = 0;
      await for (final chunk in response.timeout(stallTimeout)) {
        final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
        await limiter?.acquire(bytes.length);
        await _writer!.write(offset, bytes);
        offset += bytes.length;
        state.downloaded = offset;
        if (offset > state.end + 1) state.end = offset - 1;
        _meter.add(bytes.length);
      }
    } on SocketException catch (e) {
      if (_pauseRequested) return;
      throw DownloadError(
        DownloadErrorCode.network,
        e.message,
        retryable: true,
      );
    } on TimeoutException {
      throw const DownloadError(
        DownloadErrorCode.network,
        'The connection stalled',
        retryable: true,
      );
    } on HttpException catch (e) {
      if (_pauseRequested) return;
      throw DownloadError(
        DownloadErrorCode.network,
        e.message,
        retryable: true,
      );
    }
    if (_pauseRequested) return;
    state.status = SegmentStatus.done;
  }

  // -- completion ----------------------------------------------------------

  Future<void> _finish() async {
    final writer = _writer!;
    await writer.flush();
    final received = _states.fold<int>(0, (n, s) => n + s.downloaded);

    final known = _snapshot.totalBytes;
    final total = known ?? received;
    if (received != total) {
      throw DownloadError(
        DownloadErrorCode.unknown,
        'Expected $total bytes but received $received',
      );
    }
    if (known == null) {
      // No size from the server: the file ends where the data did.
      await writer.close();
      final trimmed = await File(_snapshot.partPath!)
          .open(mode: FileMode.append);
      await trimmed.truncate(total);
      await trimmed.close();
    } else {
      await writer.close();
    }
    await File(_snapshot.partPath!).rename(_snapshot.finalPath!);
    _snapshot = _snapshot.copyWith(
      totalBytes: total,
      segments: _currentSegments(),
    );
  }

  // -- state ---------------------------------------------------------------

  List<Segment> _currentSegments() => [for (final s in _states) s.toSegment()];

  void _setStatus(DownloadStatus status, {bool clearError = false}) {
    _snapshot = _snapshot.copyWith(
      status: status,
      segments: _states.isEmpty ? null : _currentSegments(),
      clearError: clearError,
    );
    _emitSnapshot();
  }

  /// Emits a snapshot that is safe to store: the segment counts are read
  /// first, then the file is flushed, so a stored `downloaded` can never be
  /// ahead of the bytes on disk.
  Future<void> _checkpoint() async {
    if (_checkpointing || _events.isClosed) return;
    if (_snapshot.status != DownloadStatus.downloading || _stopping) return;
    _checkpointing = true;
    try {
      final segments = _currentSegments();
      await _writer?.flush();
      if (_events.isClosed || _snapshot.status != DownloadStatus.downloading) {
        return;
      }
      _snapshot = _snapshot.copyWith(segments: segments);
      _emitSnapshot();
    } on Object {
      // A failed flush will surface through the next write.
    } finally {
      _checkpointing = false;
    }
  }

  void _emitProgress() {
    if (_events.isClosed) return;
    final done = _states.fold<int>(0, (n, s) => n + s.downloaded);
    final total = _snapshot.totalBytes;
    _events.add(
      ProgressEvent(
        id: _snapshot.id,
        downloadedBytes: done,
        totalBytes: total,
        bytesPerSecond: _meter.bytesPerSecond,
        eta: total == null ? null : _meter.eta(total - done),
        segmentBytes: [for (final s in _states) s.downloaded],
        segments: _currentSegments(),
      ),
    );
  }

  void _emitSnapshot() {
    if (!_events.isClosed) _events.add(SnapshotEvent(_snapshot));
  }
}
