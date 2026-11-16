import 'package:flutter/widgets.dart';

import 'theme/haul_theme.dart';

/// The Haul mark: the white-on-dark version in the dark theme and the
/// dark-on-white version in the light theme. The Dock icon is always the dark
/// one; this is only for inside the app.
class HaulMark extends StatelessWidget {
  const HaulMark({this.size = 28, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = HaulTheme.of(context).isDark;
    return Image.asset(
      dark
          ? 'assets/brand/in-app/haul-mark-on-dark-256.png'
          : 'assets/brand/in-app/haul-mark-on-light-256.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Haul',
    );
  }
}
