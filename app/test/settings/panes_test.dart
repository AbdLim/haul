import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/data/site_rules_repository.dart';
import 'package:haul/features/settings/settings_pane.dart';

import '../support/app_harness.dart';
import '../support/test_deps.dart';
import '../support/widget_host.dart';

Future<void> open(WidgetTester tester, SettingsPane pane) async {
  cubit<ShellCubit>(tester).showSettings(pane: pane);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder fieldLabelled(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is HaulTextField && w.semanticLabel == label,
  ),
  matching: find.byType(EditableText),
);

Future<void> typeAndAdd(WidgetTester tester, String label, String text) async {
  await tester.enterText(fieldLabelled(label), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

Future<void> settleDb(WidgetTester tester) async {
  await tester.runAsync(() => realDelay());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('File types', () {
    haulTest('adding an extension stores it, cleaned', (tester) async {
      final env = await boot(tester);
      await open(tester, SettingsPane.fileTypes);
      await typeAndAdd(tester, 'Add an extension', '  .ISO ');
      await settleDb(tester);
      expect(env.deps.settings.get(Keys.interceptExtensions), contains('iso'));
      expect(find.text('iso'), findsOneWidget);
      await shutDown(tester, env);
    });

    haulTest('removing an extension drops it', (tester) async {
      final env = await boot(tester);
      await tester.runAsync(
        () => env.deps.settings.set(Keys.interceptExtensions, ['zip', 'iso']),
      );
      await open(tester, SettingsPane.fileTypes);
      await tester.tap(find.byType(HaulChip).first);
      await settleDb(tester);
      expect(env.deps.settings.get(Keys.interceptExtensions), ['iso']);
      await shutDown(tester, env);
    });

    haulTest('the minimum size is saved', (tester) async {
      final env = await boot(tester);
      await open(tester, SettingsPane.fileTypes);
      await tester.tap(find.byType(HaulDropdown<int>));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('10 MB'));
      await settleDb(tester);
      expect(env.deps.settings.get(Keys.interceptMinBytes), 10485760);
      await shutDown(tester, env);
    });

    haulTest('an excluded site keeps its connection cap', (tester) async {
      final env = await boot(tester);
      await tester.runAsync(
        () => env.deps.siteRules.save(
          const SiteRule(host: 'example.com', maxConnections: 2),
        ),
      );
      await open(tester, SettingsPane.fileTypes);
      await typeAndAdd(tester, 'Add a site', 'https://Example.com/files');
      await settleDb(tester);
      final rules = (await tester.runAsync(env.deps.siteRules.all))!;
      expect(rules.single.host, 'example.com');
      expect(rules.single.neverIntercept, isTrue);
      expect(rules.single.maxConnections, 2);
      await shutDown(tester, env);
    });
  });

  group('Save to', () {
    haulTest('lists every category with its folder', (tester) async {
      final env = await boot(tester);
      await open(tester, SettingsPane.saveTo);
      for (final name in [
        'Compressed',
        'Documents',
        'Music',
        'Video',
        'Programs',
        'Other',
      ]) {
        expect(find.text(name), findsWidgets);
      }
      await shutDown(tester, env);
    });

    haulTest('choosing a folder changes where the next one is saved', (
      tester,
    ) async {
      final env = await boot(tester);
      (env.deps.folderPicker as FakeFolderPicker).next = '/Volumes/Big/Video';
      await open(tester, SettingsPane.saveTo);
      final videoSection = find.ancestor(
        of: find.text('Video'),
        matching: find.byType(Column),
      );
      expect(videoSection, findsWidgets);
      // The Video block is the fourth category; its Choose button is the
      // fourth after the default-folder one.
      final choose = find.text('Choose…');
      await tester.ensureVisible(choose.at(4));
      await tester.tap(choose.at(4));
      await settleDb(tester);
      final video = (await tester.runAsync(env.deps.categories.all))!
          .firstWhere((c) => c.name == 'Video');
      expect(video.saveDir, '/Volumes/Big/Video');
      expect(
        await tester.runAsync(() => env.deps.categories.saveDirFor('a.mp4')),
        '/Volumes/Big/Video',
      );
      await shutDown(tester, env);
    });

    haulTest('adding an extension to a category moves files into it', (
      tester,
    ) async {
      final env = await boot(tester);
      await open(tester, SettingsPane.saveTo);
      await typeAndAdd(tester, 'Add an extension to Video', 'ogv');
      await settleDb(tester);
      final c = await tester.runAsync(
        () => env.deps.categories.categoryFor('x.ogv'),
      );
      expect(c!.name, 'Video');
      await shutDown(tester, env);
    });

    haulTest('Reset this pane puts folders back', (tester) async {
      final env = await boot(tester);
      final video = (await tester.runAsync(env.deps.categories.all))!
          .firstWhere((c) => c.name == 'Video');
      await tester.runAsync(() async {
        await env.deps.categories.setSaveDir(video.id, '/elsewhere');
        await env.deps.categories.setExtensions(video.id, ['xyz']);
      });
      await open(tester, SettingsPane.saveTo);
      await tester.tap(find.text('Reset this pane'));
      // A chain of database calls started in the test's fake-time zone
      // advances one step per real delay and microtask flush.
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(() => realDelay(30));
        await tester.pump();
      }
      final after = (await tester.runAsync(env.deps.categories.all))!
          .firstWhere((c) => c.name == 'Video');
      expect(after.saveDir, video.saveDir);
      expect(after.extensions, video.extensions);
      await shutDown(tester, env);
    });
  });

  group('Downloads', () {
    haulTest('the duplicate and auto-remove choices are saved', (tester) async {
      final env = await boot(tester);
      await open(tester, SettingsPane.downloads);

      await tester.tap(find.byType(HaulDropdown<DuplicateAction>));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Add a numbered copy'));
      await settleDb(tester);
      expect(
        env.deps.settings.get(Keys.duplicateAction),
        DuplicateAction.numberedCopy,
      );

      await tester.tap(find.byType(HaulDropdown<AutoRemove>));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('After 7 days'));
      await settleDb(tester);
      expect(
        env.deps.settings.get(Keys.autoRemoveCompleted),
        AutoRemove.afterSevenDays,
      );
      await shutDown(tester, env);
    });

    haulTest('the user agent is saved as typed and empty clears it', (
      tester,
    ) async {
      final env = await boot(tester);
      await open(tester, SettingsPane.downloads);
      final field = fieldLabelled('Default user agent');
      await tester.enterText(field.first, 'MyAgent/1');
      await settleDb(tester);
      expect(env.deps.settings.get(Keys.defaultUserAgent), 'MyAgent/1');
      await tester.enterText(field.first, '');
      await settleDb(tester);
      expect(env.deps.settings.get(Keys.defaultUserAgent), isNull);
      await shutDown(tester, env);
    });

    haulTest('the number of simultaneous downloads follows the slider', (
      tester,
    ) async {
      final env = await boot(tester);
      await open(tester, SettingsPane.downloads);
      expect(find.text('3'), findsOneWidget);
      await tester.runAsync(
        () => env.deps.settings.set(Keys.maxConcurrentDownloads, 6),
      );
      await settleDb(tester);
      expect(find.text('6'), findsOneWidget);
      await shutDown(tester, env);
    });
  });
}
