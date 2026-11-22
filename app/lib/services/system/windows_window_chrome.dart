import 'dart:ui';

import 'package:window_manager/window_manager.dart';

import 'window_chrome.dart';

/// The window Windows users expect: an ordinary title bar, a size it cannot
/// be shrunk below, and a maximise button. There is no see-through sidebar,
/// so [applyBrightness] has nothing to do.
class WindowsWindowChrome implements WindowChrome {
  WindowsWindowChrome({Window? window}) : _cached = window;

  Window? _cached;

  Window? get _window => _cached ??= WindowManager.instance.getCurrent();

  @override
  bool get blursSidebar => false;

  @override
  Future<void> setup({bool hasSavedFrame = false}) async {
    // The runner creates the window before Dart starts and window_manager's
    // native API has no initialise step of its own, so the window is normally
    // here already. When the platform has not reported it yet, wait for it
    // rather than let the size and the minimum quietly go unset.
    final window = _window ?? await _windowWhenReady();
    if (window == null) return;
    window.minimumSize = minimumWindowSize.toNative();
    if (!hasSavedFrame) {
      window.setSize(initialWindowSize.toNative(), false);
      window.center();
    }
  }

  Future<Window?> _windowWhenReady() async {
    for (var tries = 0; tries < _windowTries; tries++) {
      await Future<void>.delayed(_windowPoll);
      final window = WindowManager.instance.getCurrent();
      if (window != null) {
        _cached = window;
        return window;
      }
    }
    return null;
  }

  @override
  Future<void> applyBrightness(Brightness brightness) async {}

  @override
  Future<void> toggleZoom() async {
    final window = _window;
    if (window == null) return;
    if (window.isMaximized) {
      window.unmaximize();
    } else {
      window.maximize();
    }
  }
}

/// How long setup waits for the platform to report its window: a fifth of a
/// second, which is far longer than the gap it covers.
const _windowTries = 10;
const _windowPoll = Duration(milliseconds: 20);
