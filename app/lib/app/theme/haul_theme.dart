import 'package:flutter/widgets.dart';

import '../../data/setting_keys.dart';
import 'haul_colors.dart';

/// Corner radii: 8 for controls, 10 for rows and cards, 14 for dialogs.
abstract final class HaulRadii {
  static const control = 8.0;
  static const row = 10.0;
  static const dialog = 14.0;
}

/// An 8-point grid, with a half step for tight spots.
abstract final class HaulSpace {
  static const half = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
}

/// The text styles. Interface text uses the macOS system font at 12, 13 and
/// 15 points (13 is the base). Space Grotesk, bundled with the app, is for
/// the wordmark, view titles and large numbers.
class HaulText {
  const HaulText(this._c);
  final HaulColors _c;

  static const _system = '.AppleSystemUIFont';
  static const _grotesk = 'SpaceGrotesk';

  /// Digits that change while someone watches must not shift sideways.
  static const _tabular = [FontFeature.tabularFigures()];

  TextStyle get body => TextStyle(
    fontFamily: _system,
    fontSize: 13,
    height: 1.35,
    color: _c.textPrimary,
    decoration: TextDecoration.none,
  );

  TextStyle get bodyStrong => body.copyWith(fontWeight: FontWeight.w600);
  TextStyle get secondary => body.copyWith(color: _c.textSecondary);
  TextStyle get caption => body.copyWith(fontSize: 12, color: _c.textSecondary);
  TextStyle get heading =>
      body.copyWith(fontSize: 15, fontWeight: FontWeight.w600);

  /// Same as [body] but with fixed-width digits, for sizes, speeds, ETAs.
  TextStyle get numeric => body.copyWith(fontFeatures: _tabular);
  TextStyle get numericSecondary => secondary.copyWith(fontFeatures: _tabular);

  /// "Haul" next to the mark.
  TextStyle get wordmark => TextStyle(
    fontFamily: _grotesk,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: _c.textPrimary,
    decoration: TextDecoration.none,
  );

  /// The title of a view, such as Settings.
  TextStyle get viewTitle => wordmark.copyWith(fontSize: 22);

  /// The big speed readout.
  TextStyle get display => TextStyle(
    fontFamily: _grotesk,
    fontSize: 34,
    fontWeight: FontWeight.w500,
    height: 1.1,
    color: _c.textPrimary,
    fontFeatures: _tabular,
    decoration: TextDecoration.none,
  );
}

/// Everything visual about the app, for one appearance.
@immutable
class HaulTheme {
  const HaulTheme({required this.brightness, required this.colors});

  static const dark = HaulTheme(
    brightness: Brightness.dark,
    colors: HaulColors.dark,
  );
  static const light = HaulTheme(
    brightness: Brightness.light,
    colors: HaulColors.light,
  );

  final Brightness brightness;
  final HaulColors colors;

  bool get isDark => brightness == Brightness.dark;

  /// Dims what is behind a dialog. Not one of the colour tokens: it is
  /// black at an opacity that suits the theme.
  Color get scrim => Color(isDark ? 0x99000000 : 0x55000000);

  /// A faint wash for a hovered row inside a floating panel, where the
  /// surface colour is already the lightest one.
  Color get hoverFill => colors.textPrimary.withAlpha(0x14);

  /// Soft shadow under floating panels such as menus and dialogs.
  Color get shadow => Color(isDark ? 0x66000000 : 0x24000000);

  HaulText get text => HaulText(colors);

  /// A blend of two themes, for the cross-fade when appearance changes.
  static HaulTheme lerp(HaulTheme a, HaulTheme b, double t) => HaulTheme(
    brightness: t < 0.5 ? a.brightness : b.brightness,
    colors: HaulColors.lerp(a.colors, b.colors, t),
  );

  static HaulTheme of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_HaulThemeData>();
    assert(scope != null, 'No HaulThemeScope above this widget');
    return scope!.theme;
  }

  static HaulTheme? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_HaulThemeData>()?.theme;
}

class _HaulThemeData extends InheritedWidget {
  const _HaulThemeData({required this.theme, required super.child});
  final HaulTheme theme;

  @override
  bool updateShouldNotify(_HaulThemeData old) => theme != old.theme;
}

class _ThemeTween extends Tween<HaulTheme> {
  _ThemeTween({required HaulTheme end}) : super(end: end);

  @override
  HaulTheme lerp(double t) => HaulTheme.lerp(begin!, end!, t);
}

/// Provides the [HaulTheme]. It follows the system appearance or the user's
/// choice, and every colour cross-fades over 200 ms when it changes.
class HaulThemeScope extends StatelessWidget {
  const HaulThemeScope({
    required this.mode,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    super.key,
  });

  final AppThemeMode mode;
  final Widget child;
  final Duration duration;

  static HaulTheme resolve(AppThemeMode mode, Brightness system) =>
      switch (mode) {
        AppThemeMode.dark => HaulTheme.dark,
        AppThemeMode.light => HaulTheme.light,
        AppThemeMode.system =>
          system == Brightness.dark ? HaulTheme.dark : HaulTheme.light,
      };

  @override
  Widget build(BuildContext context) {
    final target = resolve(mode, MediaQuery.platformBrightnessOf(context));
    return TweenAnimationBuilder<HaulTheme>(
      tween: _ThemeTween(end: target),
      duration: duration,
      curve: Curves.easeInOut,
      builder: (context, theme, _) => _HaulThemeData(
        theme: theme,
        child: DefaultTextStyle(style: theme.text.body, child: child),
      ),
    );
  }
}
