import 'dart:async';

import 'package:download_engine/download_engine.dart';

import 'database.dart';
import 'downloads_dao.dart';
import 'setting_keys.dart';

/// The one place that talks to the engine. It owns the engine, mirrors its
/// events into the database, and exposes streams for the UI. Nothing else in
/// the app calls the engine directly.
class DownloadsRepository {
  DownloadsRepository({
    required EngineApi engine,
    required HaulDatabase database,
    this.saveInterval = const Duration(seconds: 1),
  }) : _engine = engine,
       _db = database {
    _sub = _engine.events.listen(_onEvent);
  }

  final EngineApi _engine;
  final HaulDatabase _db;

  /// Database writes for one download are at least this far apart, except
  /// that every status change is written at once.
  final Duration saveInterval;

  late final StreamSubscription<EngineEvent> _sub;
  final _writers = <String, _Writer>{};
  final _progress = StreamController<ProgressEvent>.broadcast();
  final _fileChanged = StreamController<String>.broadcast();
  final _sources = <String, String>{};
  bool _disposed = false;

  /// Number of database saves so far. For tests.
  int saveCount = 0;

  // -- reading -------------------------------------------------------------

  Stream<List<StoredDownload>> watchDownloads() => _db.downloadsDao.watchAll();
  Stream<StoredDownload?> watchDownload(String id) =>
      _db.downloadsDao.watchOne(id);
  Future<List<StoredDownload>> downloads() => _db.downloadsDao.all();

  /// Live numbers (speed, ETA, per-segment bytes), a few times a second.
  Stream<ProgressEvent> get progress => _progress.stream;

  /// The id of a download whose file changed on the server and restarted.
  Stream<String> get fileChanged => _fileChanged.stream;

  // -- commands ------------------------------------------------------------

  /// Records the download and hands it to the engine.
  Future<void> add(
    DownloadRequest request, {
    String source = 'manual',
    int? categoryId,
  }) async {
    _sources[request.id] = source;
    final fresh = DownloadSnapshot(request: request);
    await _db.downloadsDao.save(fresh, source: source, categoryId: categoryId);
    saveCount++;
    _engine.add(request);
  }

  /// Hands an already stored download to the engine. It comes back paused.
  void restore(StoredDownload d) {
    _sources[d.id] = d.source;
    _engine.add(d.snapshot.request, snapshot: d.snapshot);
  }

  /// Call once at launch. Hands every stored download back to the engine.
  ///
  /// Downloads that were running when the app last stopped (saved as
  /// `downloading`, `probing` or `queued`) come back paused, and are then
  /// resumed in the order they were added if [resumeOnLaunch] is on.
  /// Paused, failed, expired and finished downloads are left as they are.
  /// A download whose `.part` file has gone starts over from zero when it
  /// resumes; the engine handles that.
  Future<void> recover({
    bool resumeOnLaunch = true,
    AutoRemove autoRemove = AutoRemove.never,
    DateTime? now,
  }) async {
    final interrupted = <String>[];
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 7));
    for (final d in await _db.downloadsDao.all()) {
      if (d.snapshot.status == DownloadStatus.completed &&
          switch (autoRemove) {
            AutoRemove.never => false,
            // "On quit" is carried out at the next start, which looks the
            // same to the person and survives a crash.
            AutoRemove.onQuit => true,
            AutoRemove.afterSevenDays =>
              (d.completedAt ?? d.createdAt).isBefore(cutoff),
          }) {
        await _db.downloadsDao.deleteById(d.id);
        continue;
      }
      final s = d.snapshot.status;
      if (s == DownloadStatus.downloading ||
          s == DownloadStatus.probing ||
          s == DownloadStatus.queued) {
        interrupted.add(d.id);
      }
      restore(d);
    }
    if (resumeOnLaunch) {
      for (final id in interrupted) {
        _engine.resume(id);
      }
    }
  }

  void pause(String id) => _engine.pause(id);
  void resume(String id) => _engine.resume(id);
  void cancel(String id) => _engine.cancel(id);
  void remove(String id) => _engine.remove(id);
  void refreshUrl(String id, Uri url, {String? referrer, String? cookies}) =>
      _engine.refreshUrl(id, url, referrer: referrer, cookies: cookies);
  void setLimits({
    int? maxConcurrentDownloads,
    int? maxConnections,
    int? speedLimitBytesPerSec,
  }) => _engine.setLimits(
    maxConcurrentDownloads: maxConcurrentDownloads,
    maxConnections: maxConnections,
    speedLimitBytesPerSec: speedLimitBytesPerSec,
  );
  void setNetwork(NetworkConfig config) => _engine.setNetwork(config);

  // -- engine events -------------------------------------------------------

  void _onEvent(EngineEvent e) {
    switch (e) {
      case SnapshotEvent():
        _writerFor(e.snapshot.id).offer(e.snapshot);
      case ProgressEvent():
        if (!_progress.isClosed) _progress.add(e);
      case FileChangedEvent():
        if (!_fileChanged.isClosed) _fileChanged.add(e.id);
      case RemovedEvent():
        final w = _writers.remove(e.id);
        w?.cancel();
        _sources.remove(e.id);
        // Let a save that is already running finish first, or it could
        // bring the row back after the delete.
        unawaited(
          (w?.flushRunning() ?? Future<void>.value()).then(
            (_) => _db.downloadsDao.deleteById(e.id),
          ),
        );
    }
  }

  _Writer _writerFor(String id) => _writers.putIfAbsent(
    id,
    () => _Writer(
      interval: saveInterval,
      save: (s) async {
        await _db.downloadsDao.save(s, source: _sources[id] ?? 'manual');
        saveCount++;
      },
    ),
  );

  /// Stops the engine, then writes whatever is still waiting to be saved.
  /// The database stays open; its owner closes it.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _engine.dispose(); // pauses running downloads, emitting snapshots
    await _sub.cancel();
    await Future.wait([for (final w in _writers.values) w.flush()]);
    await _progress.close();
    await _fileChanged.close();
  }
}

/// Throttles saves for one download: a status change goes straight to the
/// database, anything else waits for the interval, and only the newest
/// waiting snapshot is ever written.
class _Writer {
  _Writer({required this.interval, required this.save});

  final Duration interval;
  final Future<void> Function(DownloadSnapshot) save;

  DownloadStatus? _lastStatus;
  DateTime? _lastWrite;
  DownloadSnapshot? _pending;
  Timer? _timer;
  Future<void> _chain = Future.value();

  void offer(DownloadSnapshot s) {
    final changed = s.status != _lastStatus;
    final last = _lastWrite;
    final due = last == null || DateTime.now().difference(last) >= interval;
    if (changed || due) {
      _write(s);
      return;
    }
    _pending = s;
    _timer ??= Timer(interval - DateTime.now().difference(last), () {
      _timer = null;
      final p = _pending;
      if (p != null) _write(p);
    });
  }

  void _write(DownloadSnapshot s) {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _lastStatus = s.status;
    _lastWrite = DateTime.now();
    // One write at a time, in order, so a slow disk never reorders them.
    _chain = _chain.then((_) => save(s)).catchError((Object _) {});
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }

  /// Waits for writes already started, without starting new ones.
  Future<void> flushRunning() => _chain;

  Future<void> flush() async {
    final p = _pending;
    if (p != null) _write(p);
    await _chain;
  }
}
