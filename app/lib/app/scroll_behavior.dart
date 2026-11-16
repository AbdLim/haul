import 'package:flutter/widgets.dart';

import 'theme/haul_theme.dart';

/// Scrolling the Mac way: the platform's own physics (rubber-banding), and a
/// thin overlay scrollbar that fades in while scrolling and out again after.
/// There is no permanent track.
class HaulScrollBehavior extends ScrollBehavior {
  const HaulScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Only the main, vertical scrolling of a view gets one; sideways strips
    // and nested lists stay bare.
    if (details.direction != AxisDirection.down &&
        details.direction != AxisDirection.up) {
      return child;
    }
    final c = HaulTheme.of(context).colors;
    return RawScrollbar(
      controller: details.controller,
      thumbColor: c.textSecondary.withAlpha(0x88),
      thickness: 6,
      radius: const Radius.circular(3),
      crossAxisMargin: 2,
      fadeDuration: const Duration(milliseconds: 250),
      timeToFade: const Duration(milliseconds: 800),
      child: child,
    );
  }
}
