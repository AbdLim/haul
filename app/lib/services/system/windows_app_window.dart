import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'app_window.dart';

/// The window Windows gives every app. window_manager does the showing and
/// hiding; the command line comes straight from Windows, because [main]
/// does not take one.
class WindowsAppWindow implements AppWindow {
  WindowsAppWindow({
    String? commandLine,
    void Function(int code)? exitApp,
    Window? window,
  }) : _commandLine = commandLine ?? windowsCommandLine(),
       _exit = exitApp ?? exit,
       _cached = window {
    _attach();
  }

  final String _commandLine;

  /// Ends the process. [QuitGuard] has already saved everything by then.
  final void Function(int code) _exit;
  final _quit = StreamController<void>.broadcast();
  ListenerId? _listener;
  Window? _cached;

  Window? get _window => _cached ??= WindowManager.instance.getCurrent();

  /// Close requests reach only the window's own listeners, so this listens on
  /// the window rather than on the manager.
  void _attach() {
    final window = _window;
    if (window == null) return;
    _listener = window.addListener(_onWindowEvent);
  }

  void _onWindowEvent(WindowEvent event) {
    if (event is! WindowCloseRequestedEvent) return;
    // Closing the window is Haul's question to ask, not Windows' decision.
    event.request.cancel();
    _quit.add(null);
  }

  @override
  Stream<void> get quitRequests => _quit.stream;

  @override
  Future<void> show() async {
    _window?.show();
    _window?.focus();
  }

  @override
  Future<void> hide() async => _window?.hide();

  @override
  Future<bool> isVisible() async => _window?.isVisible ?? false;

  @override
  Future<bool> startedHidden() async =>
      startedHiddenFromCommandLine(_commandLine);

  /// Windows does not remember a window's place for the app, and Haul does
  /// not save it yet, so every launch opens at the size and place Haul picks.
  @override
  Future<bool> hasSavedFrame() async => false;

  @override
  Future<void> quit() async {
    final listener = _listener;
    _listener = null;
    if (listener != null) _cached?.removeListener(listener);
    await _quit.close();
    _exit(0);
  }
}

/// Whether Haul was started by the login item, which passes `--hidden`.
bool startedHiddenFromCommandLine(String commandLine) =>
    RegExp(r'(^|\s)--hidden(\s|$)').hasMatch(commandLine);

/// The whole command line Windows started Haul with, quoted arguments and
/// all, as `--hidden` is one of them.
String windowsCommandLine() {
  final getCommandLineW = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<Pointer<Utf16> Function(), Pointer<Utf16> Function()>(
        'GetCommandLineW',
      );
  return getCommandLineW().toDartString();
}
