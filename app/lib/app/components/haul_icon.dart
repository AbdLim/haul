import 'package:flutter/widgets.dart';

import '../theme/haul_theme.dart';

/// Haul's icons: Phosphor, regular weight, and nothing else. Every icon in
/// the app is one of these.
///
/// They come from the Phosphor font bundled with the app. The usual
/// `phosphor_flutter` package no longer compiles on current Flutter, so the
/// font is used directly, and each icon is its codepoint in that font.
abstract final class HaulIcons {
  static const _family = 'PhosphorRegular';

  static const check = IconData(0xe182, fontFamily: _family);
  static const close = IconData(0xe4f6, fontFamily: _family);
  static const caretDown = IconData(0xe136, fontFamily: _family);
  static const caretRight = IconData(0xe13a, fontFamily: _family);
  static const search = IconData(0xe30c, fontFamily: _family);
  static const link = IconData(0xe2e2, fontFamily: _family);
  static const pause = IconData(0xe39e, fontFamily: _family);
  static const play = IconData(0xe3d0, fontFamily: _family);
  static const plus = IconData(0xe3d4, fontFamily: _family);
  static const trash = IconData(0xe4a6, fontFamily: _family);
  static const folder = IconData(0xe256, fontFamily: _family);
  static const gear = IconData(0xe272, fontFamily: _family);
  static const warning = IconData(0xe4e0, fontFamily: _family);
  static const arrowDown = IconData(0xe03e, fontFamily: _family);
  static const list = IconData(0xe2f0, fontFamily: _family);
  static const file = IconData(0xe230, fontFamily: _family);
  static const copy = IconData(0xe1ca, fontFamily: _family);
  static const retry = IconData(0xe036, fontFamily: _family);
  static const open = IconData(0xe5de, fontFamily: _family);

  // Categories and file types.
  static const fileZip = IconData(0xe958, fontFamily: _family);
  static const fileText = IconData(0xe23a, fontFamily: _family);
  static const music = IconData(0xe33c, fontFamily: _family);
  static const video = IconData(0xe8c2, fontFamily: _family);
  static const program = IconData(0xe390, fontFamily: _family);

  // Status.
  static const download = IconData(0xe028, fontFamily: _family);
  static const pauseCircle = IconData(0xe3a0, fontFamily: _family);
  static const checkCircle = IconData(0xe184, fontFamily: _family);
  static const warningCircle = IconData(0xe4e2, fontFamily: _family);
  static const listAll = IconData(0xe2f2, fontFamily: _family);
}

class HaulIcon extends StatelessWidget {
  const HaulIcon(this.icon, {this.size = 16, this.color, super.key});

  final IconData icon;
  final double size;

  /// Defaults to the primary text colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    return Icon(icon, size: size, color: color ?? theme.colors.textPrimary);
  }
}
