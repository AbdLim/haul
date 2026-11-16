import 'package:flutter/widgets.dart';

import '../theme/haul_theme.dart';
import 'motion.dart';

/// A number that glides to its new value over 300 ms (ease out) instead of
/// jumping, drawn with tabular figures so the digits never shift sideways.
///
/// [format] turns the in-between values into text, so the same widget serves
/// speeds ("4.2 MB/s"), sizes ("128 MB of 1.2 GB") and counts. With Reduce
/// Motion on, the number changes at once.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    required this.value,
    required this.format,
    this.style,
    this.maxLines = 1,
    super.key,
  });

  final double value;
  final String Function(double value) format;

  /// Defaults to the theme's numeric body style.
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final base = style ?? theme.text.numeric;
    // Make sure whatever style is passed still has fixed-width digits.
    final textStyle = base.copyWith(
      fontFeatures: [
        ...?base.fontFeatures,
        if (!(base.fontFeatures?.contains(const FontFeature.tabularFigures()) ??
            false))
          const FontFeature.tabularFigures(),
      ],
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: Motion.reduce(context) ? Duration.zero : Motion.number,
      curve: Motion.easeOut,
      builder: (context, v, _) => Text(
        format(v),
        style: textStyle,
        maxLines: maxLines,
        overflow: TextOverflow.clip,
      ),
    );
  }
}
