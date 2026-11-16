import 'package:download_engine/download_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/app/cubits/update_cubit.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/features/settings/settings_pane.dart';
import 'package:haul/features/updates/update_banner.dart';
import 'package:haul/services/updates/update_checker.dart';

import '../support/app_harness.dart';
import '../support/test_deps.dart';
import '../support/widget_host.dart';

const info = UpdateInfo(
  version: '1.0.1',
  notes:
      '## Fixed\n- Pause works while connecting\n\n'
      '## What\'s Changed\n* Fix it by @someone in https://github.com/abdlim/haul/pull/7\n\n'
      '**Full Changelog**: https://github.com/abdlim/haul/compare/v1.0.0...v1.0.1',
  pageUrl: 'https://github.com/abdlim/haul/releases/tag/v1.0.1',
  downloadUrl: 'https://github.com/abdlim/haul/releases/download/v1.0.1/Haul-1.0.1-unsigned.dmg',
  fileName: 'Haul-1.0.1-unsigned.dmg',
  size: 25000000,
);

Future<void> found(WidgetTester tester, Env env, [UpdateInfo? i = info]) async {
  (env.deps.updateSource! as FakeUpdateSource).answer = i;
  await tester.runAsync(cubit<UpdateCubit>(tester).checkNow);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  haulTest('no banner until a newer version is found', (tester) async {
    final env = await boot(tester);
    expect(find.byType(UpdateBanner), findsOneWidget);
    expect(find.textContaining('is available'), findsNothing);
    await found(tester, env);
    expect(find.text('Haul 1.0.1 is available'), findsOneWidget);
    expect(find.text('You have 1.0.0.'), findsOneWidget);
    await shutDown(tester, env);
  });

  haulTest('"Later" closes the banner', (tester) async {
    final env = await boot(tester);
    await found(tester, env);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is HaulIconButton && w.tooltip == 'Later',
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Haul 1.0.1 is available'), findsNothing);
    await shutDown(tester, env);
  });

  haulTest("What's new shows the notes, and Skip hides the version", (
    tester,
  ) async {
    final env = await boot(tester);
    await found(tester, env);
    await tester.tap(find.text("What's new"));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HaulDialog), findsOneWidget);
    final shown = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .join('\n');
    expect(shown, contains('Pause works while connecting'));
    expect(shown, contains('Full Changelog'));
    expect(shown, isNot(contains('## ')));
    expect(shown, isNot(contains('**')));

    await tester.tap(find.text('Skip this version'));
    await tester.runAsync(() => realDelay());
    await tester.pumpAndSettle();
    expect(find.text('Haul 1.0.1 is available'), findsNothing);
    expect(env.deps.settings.get(Keys.skippedUpdate), '1.0.1');
    await shutDown(tester, env);
  });

  haulTest('View on GitHub opens the release page', (tester) async {
    final env = await boot(tester);
    await found(tester, env);
    await tester.tap(find.text("What's new"));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('View on GitHub'));
    await tester.pump();
    expect((env.deps.platform as FakePlatform).openedUrls, [info.pageUrl]);
    await shutDown(tester, env);
  });

  haulTest('Download adds the DMG to Haul\'s own list', (tester) async {
    final env = await boot(tester);
    await found(tester, env);
    await tester.tap(find.text('Download'));
    await tester.runAsync(() => realDelay());
    await tester.pump(const Duration(milliseconds: 300));
    final stored = (await tester.runAsync(env.deps.downloads.downloads))!
        .single;
    expect(stored.source, 'update');
    expect(stored.snapshot.request.url.toString(), info.downloadUrl);
    expect(stored.snapshot.request.fileName, 'Haul-1.0.1-unsigned.dmg');
    expect(env.engine.commands.whereType<AddCommand>(), hasLength(1));
    await shutDown(tester, env);
  });

  haulTest('with no DMG on the release, Download opens its page', (
    tester,
  ) async {
    final env = await boot(tester);
    await found(
      tester,
      env,
      const UpdateInfo(
        version: '1.0.1',
        notes: '',
        pageUrl: 'https://github.com/abdlim/haul/releases/tag/v1.0.1',
      ),
    );
    await tester.tap(find.text('Download'));
    await tester.runAsync(() => realDelay());
    await tester.pump();
    expect((env.deps.platform as FakePlatform).openedUrls, hasLength(1));
    expect(await tester.runAsync(env.deps.downloads.downloads), isEmpty);
    await shutDown(tester, env);
  });

  group('Settings, About', () {
    Future<void> openAbout(WidgetTester tester) async {
      cubit<ShellCubit>(tester).showSettings(pane: SettingsPane.about);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Finder checkNowButton() => find.byWidgetPredicate(
      (w) => w is HaulButton && w.label == 'Check now',
    );

    haulTest('Check now reports an up-to-date Haul', (tester) async {
      final env = await boot(tester);
      await openAbout(tester);
      await tester.runAsync(() async {
        await tester.tap(checkNowButton());
        await realDelay();
      });
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Haul is up to date.'), findsOneWidget);
      await shutDown(tester, env);
    });

    haulTest('Check now says when it cannot check', (tester) async {
      final env = await boot(tester);
      (env.deps.updateSource! as FakeUpdateSource).failure =
          const UpdateCheckException('Could not reach GitHub.');
      await openAbout(tester);
      await tester.runAsync(() async {
        await tester.tap(checkNowButton());
        await realDelay();
      });
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Could not reach GitHub.'), findsOneWidget);
      await shutDown(tester, env);
    });

    haulTest('the automatic check can be switched off', (tester) async {
      final env = await boot(tester);
      await openAbout(tester);
      expect(env.deps.settings.get(Keys.checkForUpdates), isTrue);
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is HaulToggle &&
              w.semanticLabel == 'Check for updates automatically',
        ),
      );
      await tester.runAsync(() => realDelay());
      expect(env.deps.settings.get(Keys.checkForUpdates), isFalse);
      await shutDown(tester, env);
    });
  });
}
