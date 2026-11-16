import 'package:flutter/widgets.dart';

import '../theme/haul_theme.dart';
import 'haul_icon.dart';
import 'pressable.dart';

/// A small removable label, such as a file extension in Settings.
class HaulChip extends StatelessWidget {
  const HaulChip({
    required this.label,
    this.onDeleted,
    this.selected = false,
    this.onPressed,
    super.key,
  });

  final String label;

  /// Shows a close button when set.
  final VoidCallback? onDeleted;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    return HaulPressable(
      onPressed: onPressed ?? onDeleted,
      semanticLabel: label,
      builder: (context, s) => FadeBox(
        color: selected
            ? c.accent.withAlpha(0x26)
            : (s.hovered ? c.bgElevated : c.bgSurface),
        radius: HaulRadii.control,
        border: Border.all(color: selected ? c.accent : c.borderSubtle),
        height: 24,
        padding: EdgeInsets.only(left: 8, right: onDeleted == null ? 8 : 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.text.caption.copyWith(
                color: selected ? c.accentText : c.textPrimary,
              ),
            ),
            if (onDeleted != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDeleted,
                child: HaulIcon(
                  HaulIcons.close,
                  size: 12,
                  color: c.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
