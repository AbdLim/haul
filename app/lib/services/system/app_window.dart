import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Showing, hiding and quitting, as the menu bar icon, the Dock and the quit
/// shortcut need them. Native code does the work; this is the Dart face of it,
/// so Windows and Linux can add their own later.
abstract class AppWindow {
  /// Brings the window to the front, un-hiding it if needed.
  Future<void> show();

  /// Hides the window. Downloads keep running.
  Future<void> hide();

  Future<bool> isVisible();

  /// Whether the window was started with `--hidden` (a login launch).
  Future<bool> startedHidden();

  /// Whether the last run's size and position were put back.
  Future<bool> hasSavedFrame();

  /// Fires when the user asks to quit (Command-Q, Dock menu). The app must
  /// answer with [quit] or by doing nothing, to stay open.
  Stream<void> get quitRequests;

  /// Quits for real, without asking again.
  Future<void> quit();

  static AppWindow get current {
    if (Platform.isMacOS) return MacOSAppWindow();
    throw UnsupportedError('No window for ${Platform.operatingSystem}');
  }
}

class MacOSAppWindow implements AppWindow {
  MacOSAppWindow() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'quitRequested') _quit.add(null);
      return null;
    });
  }

  static const _channel = MethodChannel('dev.haul.app/window');
  final _quit = StreamController<void>.broadcast();

  @override
  Stream<void> get quitRequests => _quit.stream;

  @override
  Future<void> show() => _channel.invokeMethod<void>('show');

  @override
  Future<void> hide() => _channel.invokeMethod<void>('hide');

  @override
  Future<bool> isVisible() async =>
      await _channel.invokeMethod<bool>('isVisible') ?? false;

  @override
  Future<bool> startedHidden() async =>
      await _channel.invokeMethod<bool>('startedHidden') ?? false;

  @override
  Future<bool> hasSavedFrame() async =>
      await _channel.invokeMethod<bool>('hasSavedFrame') ?? false;

  @override
  Future<void> quit() => _channel.invokeMethod<void>('quit');
}

/// For tests and previews.
class FakeAppWindow implements AppWindow {
  bool visible = true;
  bool hiddenLaunch = false;
  bool quitCalled = false;
  int shows = 0;
  final _quit = StreamController<void>.broadcast();

  /// Pretends the user pressed Command-Q.
  void requestQuit() => _quit.add(null);

  @override
  Stream<void> get quitRequests => _quit.stream;

  @override
  Future<void> show() async {
    visible = true;
    shows++;
  }

  @override
  Future<void> hide() async => visible = false;

  @override
  Future<bool> isVisible() async => visible;

  @override
  Future<bool> startedHidden() async => hiddenLaunch;

  @override
  Future<bool> hasSavedFrame() async => false;

  @override
  Future<void> quit() async => quitCalled = true;
}
