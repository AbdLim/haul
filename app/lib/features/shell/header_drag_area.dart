import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// The header band: dragging empty parts of it moves the window, and
/// double-clicking them zooms, as a title bar would.
///
/// The drag and double-click handling is a layer *behind* [child], not a
/// parent of it. A parent that listens for double-clicks makes Flutter hold
/// back every tap on the buttons inside it for about 300 ms while it waits to
/// see if a second click follows. Behind the content, buttons and the search
/// field answer at once, and clicks on gaps and plain text fall through to
/// the layer below.
class HeaderDragArea extends StatelessWidget {
  const HeaderDragArea({
    required this.onDoubleTap,
    required this.child,
    this.enabled = true,
    super.key,
  });

  final VoidCallback onDoubleTap;
  final Widget child;

  /// Off in tests, where there is no native window to drag.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final background = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: onDoubleTap,
      child: const SizedBox.expand(),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: enabled ? DragToMoveArea(child: background) : background,
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
