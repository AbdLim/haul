import 'package:flutter/widgets.dart';

import '../../app/components/components.dart';
import '../../app/motion/animated_number.dart';
import '../../app/motion/motion.dart';
import '../../app/theme/haul_theme.dart';

/// One filter row: an icon, a name, and a count. It owns no highlight; the
/// sidebar slides one highlight shape behind all the rows.
class SidebarItem extends StatelessWidget {
  const SidebarItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  static const height = 32.0;

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    return HaulPressable(
      onPressed: onPressed,
      semanticLabel: '$label, $count',
      scale: false,
      builder: (context, s) {
        final fg = selected
            ? c.accentText
            : (s.hovered ? c.textPrimary : c.textSecondary);
        return SizedBox(
          height: height,
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.hover),
            curve: Motion.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: s.hovered && !selected
                  ? theme.hoverFill
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(HaulRadii.control),
            ),
            child: Row(
              children: [
                HaulIcon(icon, size: 16, color: fg),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: Motion.of(context, Motion.hover),
                    style: theme.text.body.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                AnimatedNumber(
                  value: count.toDouble(),
                  format: (v) => v.round().toString(),
                  style: theme.text.numericSecondary.copyWith(
                    color: selected ? c.accentText : c.textSecondary,
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
