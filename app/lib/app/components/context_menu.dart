import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'menu.dart';

/// Opens a menu where the user right-clicks (or Control-clicks) its child.
///
/// [entriesBuilder] runs at that moment, so the menu can reflect the current
/// state, such as which downloads are selected.
class HaulContextMenuRegion extends StatelessWidget {
  const HaulContextMenuRegion({
    required this.entriesBuilder,
    required this.child,
    this.onOpen,
    super.key,
  });

  final List<HaulMenuEntry> Function(BuildContext context) entriesBuilder;
  final Widget child;

  /// Called just before the menu opens, for example to select the row that
  /// was clicked.
  final VoidCallback? onOpen;

  void _open(BuildContext context, Offset position) {
    onOpen?.call();
    final entries = entriesBuilder(context);
    if (entries.isEmpty) return;
    showHaulMenu(context, entries: entries, position: position);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        final secondary = e.buttons == kSecondaryMouseButton;
        final controlClick =
            e.buttons == kPrimaryMouseButton &&
            HardwareKeyboard.instance.isControlPressed;
        if (secondary || controlClick) _open(context, e.position);
      },
      child: child,
    );
  }
}
