import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/haul_theme.dart';
import 'haul_icon.dart';

/// One line of a menu.
sealed class HaulMenuEntry {
  const HaulMenuEntry();
}

class HaulMenuItem extends HaulMenuEntry {
  const HaulMenuItem({
    required this.label,
    required this.onSelected,
    this.icon,
    this.shortcut,
    this.destructive = false,
    this.checked = false,
  });

  final String label;

  /// Null makes the item unavailable.
  final VoidCallback? onSelected;
  final IconData? icon;

  /// Text such as "⌘N", shown at the right. Display only.
  final String? shortcut;

  /// Drawn in the danger colour, for things like Delete.
  final bool destructive;

  /// Shows a tick, for the current choice in a dropdown.
  final bool checked;

  bool get enabled => onSelected != null;
}

class HaulMenuDivider extends HaulMenuEntry {
  const HaulMenuDivider();
}

/// Marks the menu panel, so a test (or a screen reader) can tell its items
/// from the same words elsewhere on screen.
const haulMenuKey = ValueKey<String>('haul-menu');

class _Up extends Intent {
  const _Up();
}

class _Down extends Intent {
  const _Down();
}

class _Choose extends Intent {
  const _Choose();
}

class _Close extends Intent {
  const _Close();
}

/// Opens a menu at [position] (or just under [anchor]) and completes when it
/// closes. Click outside, Escape, or choosing an item closes it.
Future<void> showHaulMenu(
  BuildContext context, {
  required List<HaulMenuEntry> entries,
  Offset? position,
  Rect? anchor,
  double minWidth = 180,
}) {
  assert(position != null || anchor != null);
  final duration = Motion.of(context, Motion.hover);
  final at = position ?? Offset(anchor!.left, anchor.bottom + 4);
  final width = anchor == null
      ? minWidth
      : (anchor.width < minWidth ? minWidth : anchor.width);
  return Navigator.of(context, rootNavigator: true).push(
    _MenuRoute(
      entries: entries,
      position: at,
      width: width,
      duration: duration,
    ),
  );
}

class _MenuRoute extends PopupRoute<void> {
  _MenuRoute({
    required this.entries,
    required this.position,
    required this.width,
    required this.duration,
  });

  final List<HaulMenuEntry> entries;
  final Offset position;
  final double width;
  final Duration duration;

  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => 'Close menu';
  @override
  Duration get transitionDuration => duration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return CustomSingleChildLayout(
      delegate: _MenuLayout(position),
      child: _MenuPanel(
        entries: entries,
        width: width,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Motion.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween(begin: 0.97, end: 1.0).animate(curved),
        alignment: Alignment.topLeft,
        child: child,
      ),
    );
  }
}

class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout(this.position);
  final Offset position;

  static const _margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest)
          .deflate(const EdgeInsets.all(_margin));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Keep the whole menu inside the window.
    final x = position.dx.clamp(
      _margin,
      (size.width - childSize.width - _margin).clamp(_margin, double.infinity),
    );
    final y = position.dy.clamp(
      _margin,
      (size.height - childSize.height - _margin).clamp(
        _margin,
        double.infinity,
      ),
    );
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuLayout old) => old.position != position;
}

class _MenuPanel extends StatefulWidget {
  const _MenuPanel({
    required this.entries,
    required this.width,
    required this.onClose,
  });

  final List<HaulMenuEntry> entries;
  final double width;
  final VoidCallback onClose;

  @override
  State<_MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<_MenuPanel> {
  int? _highlight;

  List<int> get _enabled => [
    for (var i = 0; i < widget.entries.length; i++)
      if (widget.entries[i] is HaulMenuItem &&
          (widget.entries[i] as HaulMenuItem).enabled)
        i,
  ];

  void _move(int direction) {
    final items = _enabled;
    if (items.isEmpty) return;
    final at = _highlight == null ? -1 : items.indexOf(_highlight!);
    final next = direction > 0
        ? items[(at + 1) % items.length]
        : items[(at <= 0 ? items.length : at) - 1];
    setState(() => _highlight = next);
  }

  void _choose(int index) {
    final item = widget.entries[index] as HaulMenuItem;
    widget.onClose();
    item.onSelected?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    return FocusScope(
      autofocus: true,
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowUp): _Up(),
          SingleActivator(LogicalKeyboardKey.arrowDown): _Down(),
          SingleActivator(LogicalKeyboardKey.enter): _Choose(),
          SingleActivator(LogicalKeyboardKey.escape): _Close(),
        },
        child: Actions(
          actions: {
            _Up: CallbackAction<_Up>(onInvoke: (_) => _move(-1)),
            _Down: CallbackAction<_Down>(onInvoke: (_) => _move(1)),
            _Choose: CallbackAction<_Choose>(
              onInvoke: (_) {
                final h = _highlight;
                if (h != null) _choose(h);
                return null;
              },
            ),
            _Close: CallbackAction<_Close>(
              onInvoke: (_) {
                widget.onClose();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: DecoratedBox(
              key: haulMenuKey,
              decoration: BoxDecoration(
                color: c.bgElevated,
                borderRadius: BorderRadius.circular(HaulRadii.row),
                border: Border.all(color: c.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadow,
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: SizedBox(
                  width: widget.width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < widget.entries.length; i++)
                        switch (widget.entries[i]) {
                          HaulMenuDivider() => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: SizedBox(
                              height: 1,
                              child: ColoredBox(color: c.borderSubtle),
                            ),
                          ),
                          final HaulMenuItem item => _Row(
                            item: item,
                            highlighted: _highlight == i,
                            onHover: (v) => setState(() {
                              if (v && item.enabled) _highlight = i;
                              if (!v && _highlight == i) _highlight = null;
                            }),
                            onTap: item.enabled ? () => _choose(i) : null,
                          ),
                        },
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.highlighted,
    required this.onHover,
    required this.onTap,
  });

  final HaulMenuItem item;
  final bool highlighted;
  final ValueChanged<bool> onHover;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    final fg = item.destructive ? c.danger : c.textPrimary;
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: item.enabled ? 1 : 0.4,
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.hover),
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: highlighted ? theme.hoverFill : const Color(0x00000000),
              borderRadius: BorderRadius.circular(HaulRadii.control - 2),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: item.checked
                      ? HaulIcon(HaulIcons.check, size: 14, color: c.accentText)
                      : item.icon == null
                      ? null
                      : HaulIcon(item.icon!, size: 14, color: fg),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.text.body.copyWith(color: fg),
                  ),
                ),
                if (item.shortcut != null) ...[
                  const SizedBox(width: 16),
                  Text(item.shortcut!, style: theme.text.caption),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
