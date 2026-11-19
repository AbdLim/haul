import 'dart:ffi';

import 'sleep_blocker.dart';

/// Asks Windows, through `SetThreadExecutionState`, to stay out of sleep while
/// a download runs. The display may still turn off; the machine stays awake.
class WindowsSleepBlocker implements SleepBlocker {
  WindowsSleepBlocker({int Function(int flags)? setState})
    : _setState = setState ?? _kernelSetState;

  final int Function(int flags) _setState;
  bool _holding = false;

  @override
  bool get holding => _holding;

  @override
  Future<void> hold() async {
    if (_holding) return;
    _holding = _setState(_continuous | _systemRequired) != 0;
  }

  @override
  Future<void> release() async {
    if (!_holding) return;
    _setState(_continuous);
    _holding = false;
  }
}

/// ES_CONTINUOUS: the state stays as set until it is changed again.
const _continuous = 0x80000000;

/// ES_SYSTEM_REQUIRED: no sleep, but the screen may go dark.
const _systemRequired = 0x00000001;

int _kernelSetState(int flags) {
  final setThreadExecutionState = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<Uint32 Function(Uint32), int Function(int)>(
        'SetThreadExecutionState',
      );
  return setThreadExecutionState(flags);
}
