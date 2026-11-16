import 'package:flutter/widgets.dart';

/// Durations and curves for every animation. No animation in the
/// app is longer than 500 ms, none blocks input, and with macOS Reduce
/// Motion on every animation becomes a fade of 120 ms or less.
abstract final class Motion {
  static const hover = Duration(milliseconds: 120);
  static const pressDown = Duration(milliseconds: 80);
  static const pressUp = Duration(milliseconds: 160);
  static const sidebarSelection = Duration(milliseconds: 220);
  static const rowIn = Duration(milliseconds: 280);
  static const rowOut = Duration(milliseconds: 220);
  static const progress = Duration(milliseconds: 250);
  static const number = Duration(milliseconds: 300);
  static const detailPanel = Duration(milliseconds: 260);
  static const dialog = Duration(milliseconds: 200);
  static const viewSwitch = Duration(milliseconds: 220);
  static const complete = Duration(milliseconds: 500);
  static const segmentSplit = Duration(milliseconds: 250);
  static const themeChange = Duration(milliseconds: 200);

  /// The most a reduced-motion animation may last.
  static const reduced = Duration(milliseconds: 120);

  static const easeOut = Curves.easeOut;
  static const easeOutCubic = Curves.easeOutCubic;
  static const easeInOutCubic = Curves.easeInOutCubic;

  /// Scale of a pressed control.
  static const pressScale = 0.97;

  /// True when the user has asked the system to reduce motion.
  static bool reduce(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [normal], or at most [reduced] when Reduce Motion is on.
  static Duration of(BuildContext context, Duration normal) =>
      reduce(context) && normal > reduced ? reduced : normal;
}

/// Shrinks its child to 0.97 while [pressed], quickly down and a little more
/// slowly back. With Reduce Motion on there is no movement at all.
class PressScale extends StatelessWidget {
  const PressScale({required this.pressed, required this.child, super.key});

  final bool pressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduce(context)) return child;
    return AnimatedScale(
      scale: pressed ? Motion.pressScale : 1,
      duration: pressed ? Motion.pressDown : Motion.pressUp,
      curve: Motion.easeOut,
      child: child,
    );
  }
}
