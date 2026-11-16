import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/haul_theme.dart';
import 'pressable.dart';

/// An on/off switch. Replaces the stock switch.
class HaulToggle extends StatelessWidget {
  const HaulToggle({
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  final bool value;

  /// Null disables the toggle.
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;
  final bool autofocus;
  final FocusNode? focusNode;

  static const _width = 36.0;
  static const _height = 20.0;

  @override
  Widget build(BuildContext context) {
    final c = HaulTheme.of(context).colors;
    return Semantics(
      toggled: value,
      child: HaulPressable(
        onPressed: onChanged == null ? null : () => onChanged!(!value),
        semanticLabel: semanticLabel,
        autofocus: autofocus,
        focusNode: focusNode,
        focusRingRadius: _height / 2,
        scale: false,
        builder: (context, s) {
          final track = value
              ? (s.hovered
                    ? Color.lerp(c.accent, c.textPrimary, 0.12)!
                    : c.accent)
              : (s.hovered ? c.borderSubtle : c.progressTrack);
          return Opacity(
            opacity: s.enabled ? 1 : 0.4,
            child: FadeBox(
              color: track,
              radius: _height / 2,
              width: _width,
              height: _height,
              child: AnimatedAlign(
                duration: Motion.of(context, Motion.hover),
                curve: Motion.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.hover),
                    width: s.pressed ? 18 : 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: value ? c.onAccent : c.textPrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
