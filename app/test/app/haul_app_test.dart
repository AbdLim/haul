import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/haul_app.dart';
import 'package:haul/data/setting_keys.dart';

import '../support/test_deps.dart';

/// Lets real database work, which a widget test's fake clock would never
/// complete, finish between frames.
Future<void> realDelay([int ms = 60]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  testWidgets('the app builds with its real wiring and shows the wordmark', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final t = await makeTestDeps();
      await tester.pumpWidget(HaulApp(deps: t.deps, native: false));
      await realDelay();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Haul'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await realDelay();
      await t.deps.dispose();
    });
  });

  testWidgets('the window effects follow the theme setting', (tester) async {
    await tester.runAsync(() async {
      final t = await makeTestDeps();
      await t.deps.settings.set(Keys.themeMode, AppThemeMode.light);

      await tester.pumpWidget(HaulApp(deps: t.deps, native: false));
      await realDelay();
      await tester.pump(const Duration(milliseconds: 300));
      expect(t.chrome.lastBrightness, Brightness.light);

      await t.deps.settings.set(Keys.themeMode, AppThemeMode.dark);
      await realDelay();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(t.chrome.lastBrightness, Brightness.dark);

      await tester.pumpWidget(const SizedBox());
      await realDelay();
      await t.deps.dispose();
    });
  });
}
