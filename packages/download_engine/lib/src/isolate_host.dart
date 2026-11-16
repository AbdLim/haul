import 'dart:async';
import 'dart:isolate';

import 'engine.dart';
import 'engine_api.dart';
import 'download_task.dart' show defaultRetryDelays;
import 'models/commands.dart';
import 'models/events.dart';

/// Runs a [DownloadEngine] in its own isolate so downloading, hashing of
/// chunks and file writes never compete with the UI thread.
///
/// It has the same interface as [DownloadEngine]. Commands and events cross
/// the isolate boundary as plain JSON maps, which is why every command and
/// event type has `toJson` and `fromJson`.
class IsolateEngine implements EngineApi {
  IsolateEngine._(this._isolate, this._commands, this._receive, this._events);

  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _receive;
  final StreamController<EngineEvent> _events;
  final _disposed = Completer<void>();
  bool _closing = false;

  /// Starts the isolate and waits until it is ready for commands.
  static Future<IsolateEngine> start({
    int maxConcurrentDownloads = 3,
    Duration stallTimeout = const Duration(seconds: 30),
    List<Duration> retryDelays = defaultRetryDelays,
    int maxFailures = 8,
  }) async {
    final receive = ReceivePort();
    final events = StreamController<EngineEvent>.broadcast();
    final ready = Completer<SendPort>();
    late final IsolateEngine engine;

    receive.listen((Object? message) {
      if (message is SendPort) {
        ready.complete(message);
      } else if (message is Map<Object?, Object?>) {
        final map = message.cast<String, Object?>();
        if (map['type'] == 'disposed') {
          if (!engine._disposed.isCompleted) engine._disposed.complete();
        } else if (!events.isClosed) {
          events.add(EngineEvent.fromJson(map));
        }
      }
    });

    final isolate = await Isolate.spawn(
      _main,
      _Init(
        receive.sendPort,
        maxConcurrentDownloads,
        stallTimeout.inMicroseconds,
        [for (final d in retryDelays) d.inMicroseconds],
        maxFailures,
      ),
      debugName: 'haul-engine',
    );
    final commands = await ready.future;
    engine = IsolateEngine._(isolate, commands, receive, events);
    return engine;
  }

  @override
  Stream<EngineEvent> get events => _events.stream;

  @override
  void send(EngineCommand command) {
    if (_closing) return;
    _commands.send(command.toJson());
  }

  /// Stops the isolate at once, with no cleanup and no final events, the way
  /// a crash would. For testing recovery; use [dispose] otherwise.
  void kill() {
    if (_closing) return;
    _closing = true;
    _isolate.kill(priority: Isolate.immediate);
    _receive.close();
    if (!_disposed.isCompleted) _disposed.complete();
    unawaited(_events.close());
  }

  @override
  Future<void> dispose() async {
    if (_closing) return _disposed.future;
    _closing = true;
    _commands.send(const <String, Object?>{'type': 'dispose'});
    await _disposed.future;
    // Let events the isolate sent just before it said "disposed" arrive.
    await Future<void>.delayed(Duration.zero);
    _receive.close();
    _isolate.kill(priority: Isolate.immediate);
    await _events.close();
  }
}

class _Init {
  const _Init(
    this.events,
    this.maxConcurrent,
    this.stallMicros,
    this.retryMicros,
    this.maxFailures,
  );
  final SendPort events;
  final int maxConcurrent;
  final int stallMicros;
  final List<int> retryMicros;
  final int maxFailures;
}

/// The isolate's entry point.
Future<void> _main(_Init init) async {
  final commands = ReceivePort();
  init.events.send(commands.sendPort);

  final engine = DownloadEngine(
    maxConcurrentDownloads: init.maxConcurrent,
    stallTimeout: Duration(microseconds: init.stallMicros),
    retryDelays: [for (final m in init.retryMicros) Duration(microseconds: m)],
    maxFailures: init.maxFailures,
  );
  engine.events.listen((e) => init.events.send(e.toJson()));

  await for (final message in commands) {
    final map = (message as Map<Object?, Object?>).cast<String, Object?>();
    if (map['type'] == 'dispose') {
      await engine.dispose();
      init.events.send(const <String, Object?>{'type': 'disposed'});
      commands.close();
      break;
    }
    engine.send(EngineCommand.fromJson(map));
  }
}
