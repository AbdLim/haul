import 'package:flutter/widgets.dart';

import '../theme/haul_theme.dart';
import 'haul_icon.dart';
import 'pressable.dart';
import 'tooltip.dart';

enum HaulButtonKind {
  /// The one action a view is mainly for. Filled with the accent.
  primary,

  /// An ordinary action: a quiet filled button with an outline.
  secondary,

  /// Text only until hovered.
  ghost,
}

/// Height of buttons and fields: desktop density, not touch density.
const haulControlHeight = 28.0;

class HaulButton extends StatelessWidget {
  const HaulButton({
    required this.label,
    required this.onPressed,
    this.kind = HaulButtonKind.secondary,
    this.icon,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final HaulButtonKind kind;
  final IconData? icon;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    return HaulPressable(
      onPressed: onPressed,
      autofocus: autofocus,
      focusNode: focusNode,
      semanticLabel: label,
      builder: (context, s) {
        final (fill, border, fg) = switch (kind) {
          HaulButtonKind.primary => (
            s.pressed
                ? Color.lerp(c.accent, const Color(0xFF000000), 0.12)!
                : s.hovered
                ? Color.lerp(c.accent, const Color(0xFFFFFFFF), 0.14)!
                : c.accent,
            null as Color?,
            c.onAccent,
          ),
          HaulButtonKind.secondary => (
            s.hovered || s.pressed ? c.bgElevated : c.bgSurface,
            c.borderSubtle,
            c.textPrimary,
          ),
          HaulButtonKind.ghost => (
            s.hovered || s.pressed ? c.bgSurface : c.bgSurface.withAlpha(0),
            null as Color?,
            s.hovered ? c.textPrimary : c.textSecondary,
          ),
        };
        return Opacity(
          opacity: s.enabled ? 1 : 0.4,
          child: FadeBox(
            color: fill,
            radius: HaulRadii.control,
            border: border == null ? null : Border.all(color: border),
            height: haulControlHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  HaulIcon(icon!, color: fg),
                  const SizedBox(width: 6),
                ],
                // A label can be longer than the space a caller has, so it
                // gives way rather than overflowing the button.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: theme.text.body.copyWith(
                      color: fg,
                      fontWeight: kind == HaulButtonKind.primary
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A square, text-less button for toolbars and rows.
class HaulIconButton extends StatelessWidget {
  const HaulIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = haulControlHeight,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Shown on hover, and read out by screen readers.
  final String tooltip;
  final double size;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    return HaulTooltip(
      message: tooltip,
      child: HaulPressable(
        onPressed: onPressed,
        autofocus: autofocus,
        focusNode: focusNode,
        semanticLabel: tooltip,
        builder: (context, s) => Opacity(
          opacity: s.enabled ? 1 : 0.4,
          child: FadeBox(
            color: s.hovered || s.pressed
                ? c.bgSurface
                : c.bgSurface.withAlpha(0),
            radius: HaulRadii.control,
            width: size,
            height: size,
            alignment: Alignment.center,
            child: HaulIcon(
              icon,
              color: s.hovered ? c.textPrimary : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
