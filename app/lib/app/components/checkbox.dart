import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/haul_theme.dart';
import 'haul_icon.dart';
import 'pressable.dart';

/// A tick box, with an optional label to its right.
class HaulCheckbox extends StatelessWidget {
  const HaulCheckbox({
    required this.value,
    required this.onChanged,
    this.label,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    return Semantics(
      checked: value,
      child: HaulPressable(
        onPressed: onChanged == null ? null : () => onChanged!(!value),
        semanticLabel: label,
        autofocus: autofocus,
        focusNode: focusNode,
        focusRingRadius: 6,
        scale: false,
        builder: (context, s) => Opacity(
          opacity: s.enabled ? 1 : 0.4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeBox(
                color: value
                    ? c.accent
                    : (s.hovered ? c.bgElevated : c.bgSurface),
                radius: 4,
                border: Border.all(color: value ? c.accent : c.borderSubtle),
                width: 16,
                height: 16,
                alignment: Alignment.center,
                child: AnimatedOpacity(
                  opacity: value ? 1 : 0,
                  duration: Motion.of(context, Motion.hover),
                  child: HaulIcon(HaulIcons.check, size: 12, color: c.onAccent),
                ),
              ),
              if (label != null) ...[
                const SizedBox(width: 8),
                Text(label!, style: theme.text.body),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
