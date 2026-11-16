import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/features/settings/settings_pane.dart';

import '../support/app_harness.dart';
import '../support/test_deps.dart';
import '../support/widget_host.dart';

Future<void> open(WidgetTester tester) async {
  cubit<ShellCubit>(tester).showSettings(pane: SettingsPane.notifications);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => realDelay());
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  haulTest('each toggle persists', (tester) async {
    final env = await boot(tester);
    await open(tester);
    // Master, finished, failed.
    final toggles = find.byType(HaulToggle);
    expect(toggles, findsNWidgets(3));
    await tester.tap(toggles.at(1));
    await settle(tester);
    expect(env.deps.settings.get(Keys.notifyOnComplete), isFalse);
    await tester.tap(toggles.at(2));
    await settle(tester);
    expect(env.deps.settings.get(Keys.notifyOnFailure), isFalse);
    await tester.tap(toggles.at(0));
    await settle(tester);
    expect(env.deps.settings.get(Keys.notificationsEnabled), isFalse);
    await shutDown(tester, env);
  });

  haulTest('turning notifications off dims and blocks the event toggles', (
    tester,
  ) async {
    final env = await boot(tester);
    await tester.runAsync(
      () => env.deps.settings.set(Keys.notificationsEnabled, false),
    );
    await open(tester);
    await tester.tap(find.byType(HaulToggle).at(1), warnIfMissed: false);
    await settle(tester);
    expect(env.deps.settings.get(Keys.notifyOnComplete), isTrue);
    await shutDown(tester, env);
  });

  haulTest('a sound picker persists, and None clears it', (tester) async {
    final env = await boot(tester);
    await open(tester);
    await settle(tester);
    await tester.tap(find.byType(HaulDropdown<String>).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Hero'));
    await settle(tester);
    expect(env.deps.settings.get(Keys.soundOnComplete), 'Hero');

    await tester.tap(find.byType(HaulDropdown<String>).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('None').last);
    await settle(tester);
    expect(env.deps.settings.get(Keys.soundOnComplete), isNull);
    await shutDown(tester, env);
  });

  haulTest('preview plays the chosen sound, and is off for None', (
    tester,
  ) async {
    final env = await boot(tester);
    final sounds = env.deps.sounds! as FakeSoundPlayer;
    await tester.runAsync(
      () => env.deps.settings.set(Keys.soundOnFailure, 'Glass'),
    );
    await open(tester);
    await settle(tester);

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is HaulIconButton && w.tooltip == 'Play Download failed sound',
      ),
    );
    await tester.pump();
    expect(sounds.played, ['Glass']);

    final none = tester.widget<HaulIconButton>(
      find.byWidgetPredicate(
        (w) =>
            w is HaulIconButton && w.tooltip == 'Play Download finished sound',
      ),
    );
    expect(none.onPressed, isNull);
    await shutDown(tester, env);
  });

  haulTest('Reset this pane restores every default', (tester) async {
    final env = await boot(tester);
    await tester.runAsync(() async {
      await env.deps.settings.set(Keys.notificationsEnabled, false);
      await env.deps.settings.set(Keys.soundOnComplete, 'Ping');
    });
    await open(tester);
    await tester.tap(find.text('Reset this pane'));
    await settle(tester);
    expect(env.deps.settings.get(Keys.notificationsEnabled), isTrue);
    expect(env.deps.settings.get(Keys.soundOnComplete), isNull);
    await shutDown(tester, env);
  });
}
