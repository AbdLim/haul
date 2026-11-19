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
    final window = _window;
    if (window == null) return;
    window.minimumSize = minimumWindowSize.toNative();
    if (!hasSavedFrame) {
      window.setSize(initialWindowSize.toNative(), false);
      window.center();
    }
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
