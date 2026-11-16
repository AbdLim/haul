import 'package:download_engine/download_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/app/version.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/features/downloads/download_row.dart';
import 'package:haul/features/settings/settings_pane.dart';
import 'package:haul/features/settings/settings_view.dart';
import 'package:haul/features/settings/settings_widgets.dart';

import '../support/app_harness.dart';
import '../support/widget_host.dart';

Future<void> open(WidgetTester tester, {SettingsPane? pane}) async {
  cubit<ShellCubit>(tester).showSettings(pane: pane);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  haulTest('a short pane starts at the top, not in the middle', (tester) async {
    final env = await boot(tester);
    for (final pane in [SettingsPane.appearance, SettingsPane.siteLogins]) {
      await open(tester, pane: pane);
      await tester.pumpAndSettle();
      // The window is 800 high; the first section title sits just under the
      // pane's header, whatever the pane's length.
      final first = find.byType(SettingsSection).first;
      expect(tester.getTopLeft(first).dy, lessThan(160), reason: pane.name);
    }
    await shutDown(tester, env);
  });

  haulTest('opens from the shell and Escape goes back', (tester) async {
    final env = await boot(tester);
    await open(tester);
    expect(find.byType(SettingsView), findsOneWidget);
    expect(find.text('Open Haul at login'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(cubit<ShellCubit>(tester).state.section, MainSection.downloads);
    await shutDown(tester, env);
  });

  haulTest('a toggle saves at once', (tester) async {
    final env = await boot(tester);
    await open(tester);
    expect(env.deps.settings.get(Keys.launchAtLogin), isFalse);
    await tester.tap(find.byType(HaulToggle).first);
    await tester.pump();
    await tester.runAsync(() => realDelay());
    expect(env.deps.settings.get(Keys.launchAtLogin), isTrue);
    await shutDown(tester, env);
  });

  haulTest('picking a pane cross-fades to it and remembers it', (tester) async {
    final env = await boot(tester);
    await open(tester);
    await tester.tap(find.text('Appearance').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('List density'), findsOneWidget);
    expect(find.text('Open Haul at login'), findsNothing);
    expect(
      cubit<ShellCubit>(tester).state.settingsPane,
      SettingsPane.appearance,
    );
    await shutDown(tester, env);
  });

  haulTest('the theme control changes the stored theme', (tester) async {
    final env = await boot(tester);
    await open(tester, pane: SettingsPane.appearance);
    await tester.tap(find.text('Light'));
    await tester.pump();
    await tester.runAsync(() => realDelay());
    expect(env.deps.settings.get(Keys.themeMode), AppThemeMode.light);
    await shutDown(tester, env);
  });

  haulTest('Reset this pane restores only that pane', (tester) async {
    final env = await boot(tester);
    await tester.runAsync(() async {
      await env.deps.settings.set(Keys.themeMode, AppThemeMode.light);
      await env.deps.settings.set(Keys.keepAwake, false);
    });
    await open(tester, pane: SettingsPane.appearance);
    await tester.tap(find.text('Reset this pane'));
    await tester.pump();
    await tester.runAsync(() => realDelay());
    expect(env.deps.settings.get(Keys.themeMode), AppThemeMode.system);
    expect(env.deps.settings.get(Keys.keepAwake), isFalse);
    await shutDown(tester, env);
  });

  haulTest('About shows the version and Reset all asks first', (tester) async {
    final env = await boot(tester);
    await tester.runAsync(() => env.deps.settings.set(Keys.keepAwake, false));
    await open(tester, pane: SettingsPane.about);
    expect(find.text(appVersion), findsOneWidget);
    await tester.tap(find.text('Reset all'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Reset all settings?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(env.deps.settings.get(Keys.keepAwake), isFalse);

    await tester.tap(find.text('Reset all'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find
          .descendant(
            of: find.byType(Directionality).last,
            matching: find.text('Reset all'),
          )
          .last,
    );
    await tester.pump();
    await tester.runAsync(() => realDelay());
    expect(env.deps.settings.get(Keys.keepAwake), isTrue);
    expect(env.deps.settings.get(Keys.bridgeToken), isNotNull);
    await shutDown(tester, env);
  });

  haulTest('the token is made at start and the port is shown', (tester) async {
    final env = await boot(tester);
    final token = env.deps.settings.get(Keys.bridgeToken);
    expect(token, isNotNull);
    expect(token!.length, 64);
    await open(tester);
    expect(find.text('47821'), findsOneWidget);
    await shutDown(tester, env);
  });

  haulTest('compact density makes the rows shorter', (tester) async {
    final env = await boot(tester);
    await seed(tester, env, 'a', 'Other', DownloadStatus.paused);
    final row = find.byType(DownloadRow);
    final comfortable = tester.getSize(row.first).height;
    await tester.runAsync(() async {
      await env.deps.settings.set(Keys.listDensity, ListDensity.compact);
      await realDelay();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(row.first).height, lessThan(comfortable));
    await shutDown(tester, env);
  });
}
