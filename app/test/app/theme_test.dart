import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/theme/haul_colors.dart';
import 'package:haul/app/theme/haul_theme.dart';
import 'package:haul/data/setting_keys.dart';

/// The colour tokens: token, dark, light.
const table = <String, (int, int)>{
  'bg.window': (0xFF14171C, 0xFFF6F7F9),
  'bg.sidebar': (0xCC101216, 0xCCECEEF2),
  'bg.surface': (0xFF1C2027, 0xFFFFFFFF),
  'bg.elevated': (0xFF232831, 0xFFFFFFFF),
  'border.subtle': (0xFF2A303A, 0xFFE1E4EA),
  'text.primary': (0xFFF4F5F7, 0xFF14171C),
  'text.secondary': (0xFFA3ABB8, 0xFF4A5360),
  'accent': (0xFFF25C05, 0xFFF25C05),
  'accent.text': (0xFFFF7A2E, 0xFFC44700),
  'on.accent': (0xFF14171C, 0xFF14171C),
  'success': (0xFF2BC275, 0xFF12894A),
  'warning': (0xFFFFB400, 0xFF9A6B00),
  'danger': (0xFFFF5D5D, 0xFFC92A2A),
  'progress.track': (0xFF2A303A, 0xFFE1E4EA),
};

void main() {
  group('colour tokens', () {
    test('both themes expose every token in the table', () {
      final dark = HaulColors.dark.toMap();
      final light = HaulColors.light.toMap();
      expect(dark.keys.toSet(), table.keys.toSet());
      expect(light.keys.toSet(), table.keys.toSet());
    });

    test('every value matches the table', () {
      final dark = HaulColors.dark.toMap();
      final light = HaulColors.light.toMap();
      for (final e in table.entries) {
        expect(dark[e.key]!.toARGB32(), e.value.$1, reason: 'dark ${e.key}');
        expect(light[e.key]!.toARGB32(), e.value.$2, reason: 'light ${e.key}');
      }
    });

    test('the sidebar is 80 percent opaque so the blur shows', () {
      expect(HaulColors.dark.bgSidebar.a, closeTo(0.8, 0.005));
      expect(HaulColors.light.bgSidebar.a, closeTo(0.8, 0.005));
    });

    test('the accent is the same orange in both themes', () {
      expect(HaulColors.dark.accent, HaulColors.light.accent);
    });

    test('lerp hits both ends and blends the middle', () {
      final mid = HaulColors.lerp(HaulColors.dark, HaulColors.light, 0.5);
      expect(
        HaulColors.lerp(HaulColors.dark, HaulColors.light, 0).bgWindow,
        HaulColors.dark.bgWindow,
      );
      expect(
        HaulColors.lerp(HaulColors.dark, HaulColors.light, 1).bgWindow,
        HaulColors.light.bgWindow,
      );
      expect(mid.bgWindow, isNot(HaulColors.dark.bgWindow));
      expect(mid.bgWindow, isNot(HaulColors.light.bgWindow));
    });
  });

  group('shape and type', () {
    test('radii and spacing follow the design values', () {
      expect(HaulRadii.control, 8);
      expect(HaulRadii.row, 10);
      expect(HaulRadii.dialog, 14);
      expect(HaulSpace.s, 8);
      expect(HaulSpace.m, 16);
      expect(HaulSpace.l, 24);
    });

    test('interface text is 12, 13 and 15 points in the system font', () {
      final t = HaulTheme.dark.text;
      expect(t.body.fontSize, 13);
      expect(t.caption.fontSize, 12);
      expect(t.heading.fontSize, 15);
      for (final s in [t.body, t.caption, t.heading, t.numeric]) {
        expect(s.fontFamily, '.AppleSystemUIFont');
      }
    });

    test('Space Grotesk is used for the wordmark, titles and big numbers', () {
      final t = HaulTheme.dark.text;
      expect(t.wordmark.fontFamily, 'SpaceGrotesk');
      expect(t.viewTitle.fontFamily, 'SpaceGrotesk');
      expect(t.display.fontFamily, 'SpaceGrotesk');
      expect(t.wordmark.fontWeight, FontWeight.w700);
      expect(t.display.fontWeight, FontWeight.w500);
    });

    test('numbers that change use tabular figures', () {
      final t = HaulTheme.dark.text;
      for (final s in [t.numeric, t.numericSecondary, t.display]) {
        expect(s.fontFeatures, contains(const FontFeature.tabularFigures()));
      }
    });

    test('text colours follow the theme', () {
      expect(HaulTheme.dark.text.body.color, HaulColors.dark.textPrimary);
      expect(HaulTheme.light.text.body.color, HaulColors.light.textPrimary);
      expect(
        HaulTheme.dark.text.secondary.color,
        HaulColors.dark.textSecondary,
      );
    });
  });

  group('HaulThemeScope', () {
    Widget app(
      AppThemeMode mode,
      Brightness system,
      void Function(HaulTheme) onTheme,
    ) {
      return MediaQuery(
        data: MediaQueryData(platformBrightness: system),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: HaulThemeScope(
            mode: mode,
            child: Builder(
              builder: (context) {
                onTheme(HaulTheme.of(context));
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    }

    testWidgets('system mode follows the platform brightness', (tester) async {
      late HaulTheme seen;
      await tester.pumpWidget(
        app(AppThemeMode.system, Brightness.dark, (t) => seen = t),
      );
      expect(seen.isDark, isTrue);
      await tester.pumpWidget(
        app(AppThemeMode.system, Brightness.light, (t) => seen = t),
      );
      await tester.pumpAndSettle();
      expect(seen.isDark, isFalse);
    });

    testWidgets('an explicit choice overrides the system', (tester) async {
      late HaulTheme seen;
      await tester.pumpWidget(
        app(AppThemeMode.light, Brightness.dark, (t) => seen = t),
      );
      expect(seen.colors.bgWindow, HaulColors.light.bgWindow);
      await tester.pumpWidget(
        app(AppThemeMode.dark, Brightness.light, (t) => seen = t),
      );
      await tester.pumpAndSettle();
      expect(seen.colors.bgWindow, HaulColors.dark.bgWindow);
    });

    testWidgets('switching appearance cross-fades over 200 ms with no jump', (
      tester,
    ) async {
      late HaulTheme seen;
      await tester.pumpWidget(
        app(AppThemeMode.dark, Brightness.dark, (t) => seen = t),
      );
      expect(seen.colors.bgWindow, HaulColors.dark.bgWindow);

      await tester.pumpWidget(
        app(AppThemeMode.light, Brightness.dark, (t) => seen = t),
      );
      // The first frame is still the old colour: no flash.
      expect(seen.colors.bgWindow, HaulColors.dark.bgWindow);

      await tester.pump(const Duration(milliseconds: 100));
      final mid = seen.colors.bgWindow;
      expect(mid, isNot(HaulColors.dark.bgWindow));
      expect(mid, isNot(HaulColors.light.bgWindow));

      await tester.pump(const Duration(milliseconds: 150));
      expect(seen.colors.bgWindow, HaulColors.light.bgWindow);
    });

    testWidgets('text defaults to the body style', (tester) async {
      TextStyle? style;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: HaulThemeScope(
              mode: AppThemeMode.dark,
              child: Builder(
                builder: (c) {
                  style = DefaultTextStyle.of(c).style;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      expect(style!.fontSize, 13);
      expect(style!.color, HaulColors.dark.textPrimary);
    });
  });
}
