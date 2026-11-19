import 'dart:async';
import 'dart:io';

import 'windows_sleep_blocker.dart';

/// Stops the computer sleeping (idle) while downloads run.
abstract class SleepBlocker {
  /// Starts holding the computer awake. Calling it again does nothing.
  Future<void> hold();

  /// Lets go. Calling it with nothing held does nothing.
  Future<void> release();

  bool get holding;

  static SleepBlocker get current {
    if (Platform.isMacOS) return CaffeinateSleepBlocker();
    if (Platform.isWindows) return WindowsSleepBlocker();
    throw UnsupportedError('No sleep blocker for ${Platform.operatingSystem}');
  }
}

typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments,
);

/// Runs `caffeinate -i -w <our pid>`: the assertion lasts while the child
/// lives, and `-w` makes it end by itself if Haul dies.
class CaffeinateSleepBlocker implements SleepBlocker {
  CaffeinateSleepBlocker({ProcessStarter? start, int? processId})
    : _start = start ?? Process.start,
      _pid = processId ?? pid;

  final ProcessStarter _start;
  final int _pid;
  Process? _process;
  bool _starting = false;

  @override
  bool get holding => _process != null || _starting;

  @override
  Future<void> hold() async {
    if (holding) return;
    _starting = true;
    try {
      _process = await _start('caffeinate', ['-i', '-w', '$_pid']);
      // If it ends by itself, we no longer hold anything.
      final started = _process!;
      unawaited(
        started.exitCode.then((_) {
          if (identical(_process, started)) _process = null;
        }),
      );
    } on Object {
      _process = null;
    } finally {
      _starting = false;
    }
  }

  @override
  Future<void> release() async {
    final p = _process;
    _process = null;
    p?.kill();
  }
}

class FakeSleepBlocker implements SleepBlocker {
  int holds = 0;
  int releases = 0;
  bool _holding = false;

  @override
  bool get holding => _holding;

  @override
  Future<void> hold() async {
    if (_holding) return;
    _holding = true;
    holds++;
  }

  @override
  Future<void> release() async {
    if (!_holding) return;
    _holding = false;
    releases++;
  }
}
