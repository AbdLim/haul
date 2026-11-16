import 'package:flutter/widgets.dart';

import 'motion.dart';

/// The one place the app asks whether to reduce motion. It reads macOS's
/// "Reduce motion" setting, which Flutter exposes as
/// `MediaQuery.disableAnimations`.
///
/// When it is on, every animation is replaced by a fade of 120 ms or less:
/// nothing slides, scales or travels.
abstract final class ReduceMotion {
  static bool of(BuildContext context) => Motion.reduce(context);

  /// [normal], capped at 120 ms when motion is reduced.
  static Duration duration(BuildContext context, Duration normal) =>
      Motion.of(context, normal);
}
