import 'dart:io';
import 'dart:ui';

import 'package:macos_window_utils/macos_window_utils.dart';

/// Native window behaviour that Flutter cannot do by itself. Everything the
/// UI needs from the window goes through this, so Windows and Linux can add
/// their own implementation later.
abstract class WindowChrome {
  /// Hidden title bar, content under the traffic lights, minimum size. A size
  /// and position saved by the last run are kept ([hasSavedFrame]).
  Future<void> setup({bool hasSavedFrame = false});

  /// Makes native effects (sidebar blur, shadows) match the app's theme.
  Future<void> applyBrightness(Brightness brightness);

  /// Toggles zoom, as double-clicking a title bar does.
  Future<void> toggleZoom();

  static WindowChrome get current {
    if (Platform.isMacOS) return MacOSWindowChrome();
    throw UnsupportedError('No window chrome for ${Platform.operatingSystem}');
  }
}

/// The smallest the window may be.
const minimumWindowSize = Size(960, 600);

/// How big it opens.
const initialWindowSize = Size(1180, 760);

class MacOSWindowChrome implements WindowChrome {
  @override
  Future<void> setup({bool hasSavedFrame = false}) async {
    await WindowManipulator.initialize(enableWindowDelegate: true);
    // No Flutter-drawn title bar: the real one is made see-through and the
    // content runs underneath it, behind the traffic lights.
    await WindowManipulator.makeTitlebarTransparent();
    await WindowManipulator.enableFullSizeContentView();
    await WindowManipulator.hideTitle();
    await WindowManipulator.setWindowBackgroundColorToClear();
    await WindowManipulator.setWindowMinSize(minimumWindowSize);
    // AppKit only enforces a minimum when the user resizes, so open at a
    // comfortable size that respects it.
    if (!hasSavedFrame) {
      await WindowManipulator.setWindowFrame(
        Rect.fromLTWH(0, 0, initialWindowSize.width, initialWindowSize.height),
      );
      await WindowManipulator.centerWindow();
    }
  }

  @override
  Future<void> applyBrightness(Brightness brightness) =>
      WindowManipulator.overrideMacOSBrightness(
        dark: brightness == Brightness.dark,
      );

  @override
  Future<void> toggleZoom() async {
    if (await WindowManipulator.isWindowZoomed()) {
      await WindowManipulator.unzoomWindow();
    } else {
      await WindowManipulator.zoomWindow();
    }
  }
}

/// For tests and previews.
class NoWindowChrome implements WindowChrome {
  int zoomToggles = 0;
  Brightness? lastBrightness;

  @override
  Future<void> setup({bool hasSavedFrame = false}) async {}

  @override
  Future<void> applyBrightness(Brightness brightness) async =>
      lastBrightness = brightness;

  @override
  Future<void> toggleZoom() async => zoomToggles++;
}
