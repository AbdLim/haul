import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Swaps one view for another with a cross-fade and a small sideways shift:
/// the new view slides in 8 points as it fades in, the old one fades out.
/// 220 ms, ease out cubic. With Reduce Motion it is a plain, shorter fade.
class ViewSwitch extends StatelessWidget {
  const ViewSwitch({required this.child, super.key});

  /// Give each view its own key, or the switch has nothing to tell apart.
  final Widget child;

  static const shift = 8.0;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduce(context);
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.viewSwitch),
      switchInCurve: Motion.easeOutCubic,
      switchOutCurve: Motion.easeOutCubic,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: reduced
            ? child
            : AnimatedBuilder(
                animation: animation,
                builder: (context, child) => Transform.translate(
                  offset: Offset((1 - animation.value) * shift, 0),
                  child: child,
                ),
                child: child,
              ),
      ),
      child: child,
    );
  }
}
