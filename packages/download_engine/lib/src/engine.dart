import 'dart:async';
import 'dart:io';

import 'download_task.dart';
import 'engine_api.dart';
import 'models/commands.dart';
import 'models/download_snapshot.dart';
import 'models/download_status.dart';
import 'models/events.dart';
import 'models/network_config.dart';
import 'network_settings.dart';
import 'rate_limiter.dart';

class _Entry {
  _Entry(this.snapshot);
  DownloadSnapshot snapshot;
  DownloadTask? task;
  bool cancelWhenStopped = false;
  bool get running => task != null;
}

/// Owns every download: a FIFO queue, up to `maxConcurrentDownloads` running
/// at once, a shared speed limit, and the command and event plumbing.
///
/// The engine never touches a database. It emits snapshots, and the app
/// stores them and hands them back through `AddCommand(snapshot: ...)`.
class DownloadEngine implements EngineApi {
  DownloadEngine({
    HttpClient? client,
    int maxConcurrentDownloads = 3,
    this.stallTimeout = const Duration(seconds: 30),
    this.retryDelays = defaultRetryDelays,
    this.maxFailures = 8,
    this.sleep,
    this.checkpointInterval = const Duration(seconds: 1),
  }) : _client = client ?? _defaultClient(),
       _ownsClient = client == null,
       _maxConcurrent = maxConcurrentDownloads;

  static HttpClient _defaultClient() => HttpClient()
    ..autoUncompress = false
    // A host that does not even accept the connection fails in 15 s instead
    // of the system's much longer wait.
    ..connectionTimeout = const Duration(seconds: 15)
    ..maxConnectionsPerHost = 16;

  final HttpClient _client;
  final bool _ownsClient;
  final Duration stallTimeout;
  final List<Duration> retryDelays;
  final int maxFailures;
  final Future<void> Function(Duration)? sleep;
  final Duration? checkpointInterval;

  final _limiter = RateLimiter();
  final _events = StreamController<EngineEvent>.broadcast();
  final _entries = <String, _Entry>{};
  final _queue = <String>[];
  final _runs = <Future<void>>{};
  int _maxConcurrent;
  int? _maxConnections;
  final _network = NetworkSettings();
  bool _disposed = false;

  @override
  Stream<EngineEvent> get events => _events.stream;

  /// Latest snapshots, for tests and for apps that want a one-off read.
  List<DownloadSnapshot> get snapshots => [
    for (final e in _entries.values) e.snapshot,
  ];

  int get runningCount => _entries.values.where((e) => e.running).length;

  @override
  void send(EngineCommand command) {
    if (_disposed) return;
    switch (command) {
      case AddCommand():
        _add(command);
      case PauseCommand():
        _pause(command.id);
      case ResumeCommand():
        _resume(command.id);
      case CancelCommand():
        _cancel(command.id);
      case RemoveCommand():
        _remove(command.id);
      case RefreshUrlCommand():
        _refresh(command);
      case SetLimitsCommand():
        _setLimits(command);
      case SetNetworkCommand():
        _setNetwork(command.config);
    }
  }

  // -- commands ------------------------------------------------------------

  void _add(AddCommand c) {
    final id = c.request.id;
    if (_entries.containsKey(id)) return;
    final saved = c.snapshot;
    if (saved == null) {
      final entry = _Entry(DownloadSnapshot(request: c.request));
      _entries[id] = entry;
      _emit(entry.snapshot);
      _enqueue(id);
      return;
    }
    // A restored download never starts by itself. Anything that was in
    // flight when the app last closed comes back paused.
    final interrupted =
        saved.status.isActive || saved.status == DownloadStatus.queued;
    final entry = _Entry(
      interrupted ? saved.copyWith(status: DownloadStatus.paused) : saved,
    );
    _entries[id] = entry;
    _emit(entry.snapshot);
  }

  void _pause(String id) {
    final entry = _entries[id];
    if (entry == null) return;
    if (entry.running) {
      unawaited(entry.task!.pause());
    } else if (entry.snapshot.status == DownloadStatus.queued) {
      _queue.remove(id);
      _update(entry, entry.snapshot.copyWith(status: DownloadStatus.paused));
    }
  }

  void _resume(String id) {
    final entry = _entries[id];
    if (entry == null || entry.running) return;
    if (!entry.snapshot.status.canResume) return;
    _update(
      entry,
      entry.snapshot.copyWith(status: DownloadStatus.queued, clearError: true),
    );
    _enqueue(id);
  }

  void _cancel(String id) {
    final entry = _entries[id];
    if (entry == null) return;
    if (entry.running) {
      entry.cancelWhenStopped = true;
      unawaited(entry.task!.pause());
      return;
    }
    _queue.remove(id);
    _discard(entry);
  }

  void _remove(String id) {
    final entry = _entries[id];
    if (entry == null || entry.running) return;
    _queue.remove(id);
    _entries.remove(id);
    _events.add(RemovedEvent(id));
  }

  void _refresh(RefreshUrlCommand c) {
    final entry = _entries[c.id];
    if (entry == null || entry.running) return;
    _queue.remove(c.id);
    _update(
      entry,
      entry.snapshot.withRefreshedUrl(
        c.url,
        referrer: c.referrer,
        cookies: c.cookies,
        userAgent: c.userAgent,
      ),
    );
    _enqueue(c.id);
  }

  void _setLimits(SetLimitsCommand c) {
    final concurrent = c.maxConcurrentDownloads;
    if (concurrent != null && concurrent > 0) _maxConcurrent = concurrent;
    final connections = c.maxConnections;
    if (connections != null && connections > 0) _maxConnections = connections;
    final speed = c.speedLimitBytesPerSec;
    if (speed != null) _limiter.bytesPerSecond = speed;
    // A higher limit lets queued downloads start; a lower one only stops
    // new starts, so running downloads are left to finish.
    _pump();
  }

  void _setNetwork(NetworkConfig config) {
    _network.config = config;
    _applyProxy(config.proxy);
  }

  /// `findProxy` is asked for every new request, so a change applies to the
  /// next request while running workers finish their current one.
  void _applyProxy(ProxyConfig? proxy) {
    if (proxy == null) {
      _client.findProxy = (_) => 'DIRECT';
      return;
    }
    final user = proxy.username;
    final pass = proxy.password ?? '';
    // Dart reads credentials out of "PROXY user:pass@host:port" without any
    // unescaping, so that form only works when they contain nothing it
    // would split on. Anything else goes through addProxyCredentials.
    final inline =
        user != null &&
        pass.isNotEmpty &&
        !user.contains(RegExp('[@:]')) &&
        !pass.contains('@');
    if (user != null && !inline) {
      _client.addProxyCredentials(
        proxy.host,
        proxy.port,
        'haul',
        HttpClientBasicCredentials(user, pass),
      );
    }
    final auth = inline ? '$user:$pass@' : '';
    _client.findProxy = (uri) => proxy.bypasses(uri.host)
        ? 'DIRECT'
        : 'PROXY $auth${proxy.host}:${proxy.port}';
  }

  // -- queue ---------------------------------------------------------------

  void _enqueue(String id) {
    if (!_queue.contains(id)) _queue.add(id);
    _pump();
  }

  void _pump() {
    while (!_disposed && runningCount < _maxConcurrent && _queue.isNotEmpty) {
      final id = _queue.removeAt(0);
      final entry = _entries[id];
      if (entry == null || entry.running) continue;
      if (entry.snapshot.status != DownloadStatus.queued) continue;
      _start(entry);
    }
  }

  void _start(_Entry entry) {
    var snapshot = entry.snapshot;
    final connections = _maxConnections;
    if (connections != null) {
      snapshot = snapshot.copyWith(
        request: snapshot.request.copyWith(maxConnections: connections),
      );
    }
    final task = DownloadTask(
      snapshot: snapshot,
      client: _client,
      limiter: _limiter,
      checkpointInterval: checkpointInterval,
      network: _network,
      stallTimeout: stallTimeout,
      retryDelays: retryDelays,
      maxFailures: maxFailures,
      sleep: sleep ?? (d) => Future<void>.delayed(d),
    );
    entry.task = task;
    // Mark it started right away; the task's own events arrive a moment later.
    entry.snapshot = snapshot.copyWith(status: DownloadStatus.probing);
    _emit(entry.snapshot);

    DownloadSnapshot? lastSeen;
    final sub = task.events.listen((e) {
      if (e is SnapshotEvent) {
        lastSeen = e.snapshot;
        entry.snapshot = e.snapshot;
      }
      if (!_events.isClosed) _events.add(e);
    });

    late final Future<void> run;
    run = task
        .run()
        .then((result) async {
          await sub.cancel();
          entry.task = null;
          if (entry.cancelWhenStopped) {
            _discard(entry);
          } else {
            entry.snapshot = result;
            if (!identical(lastSeen, result) &&
                lastSeen?.status != result.status) {
              _emit(result);
            }
          }
          _pump();
        })
        .whenComplete(() => _runs.remove(run));
    _runs.add(run);
  }

  /// Cancel: delete the partial file and forget the download.
  void _discard(_Entry entry) {
    final part = entry.snapshot.partPath;
    if (part != null) {
      final f = File(part);
      if (f.existsSync()) f.deleteSync();
    }
    _entries.remove(entry.snapshot.id);
    _events.add(RemovedEvent(entry.snapshot.id));
  }

  // -- events --------------------------------------------------------------

  void _update(_Entry entry, DownloadSnapshot s) {
    entry.snapshot = s;
    _emit(s);
  }

  void _emit(DownloadSnapshot s) {
    if (!_events.isClosed) _events.add(SnapshotEvent(s));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    // Set first so finishing downloads don't start queued ones.
    _disposed = true;
    for (final e in _entries.values) {
      if (e.running) unawaited(e.task!.pause());
    }
    await Future.wait(_runs.toList());
    await _events.close();
    if (_ownsClient) _client.close(force: true);
  }
}
