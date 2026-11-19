import 'package:download_engine/download_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/cubits/browser_status_cubit.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/app/error_text.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/features/downloads/empty_state.dart';
import 'package:haul/features/downloads/first_run_card.dart';
import 'package:haul/app/platform_names.dart';

import '../support/app_harness.dart';
import '../support/widget_host.dart';
import 'downloads_list_test.dart' show snap;

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => realDelay());
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('empty list', () {
    haulTest('a new install invites the first download', (tester) async {
      final env = await boot(tester);
      expect(find.byType(DownloadsEmptyState), findsOneWidget);
      expect(
        find.text(
          'Paste a link or press ${PlatformNames.commandSymbol}N to add a '
          'download',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(DownloadsEmptyState),
          matching: find.text('Add URL'),
        ),
      );
      await tester.pump();
      expect(cubit<ShellCubit>(tester).state.addDialogOpen, isTrue);
      await shutDown(tester, env);
    });

    haulTest('it goes away when there is a download', (tester) async {
      final env = await boot(tester);
      await seedSnapshot(
        tester,
        env,
        snap('a', DownloadStatus.paused),
        'Compressed',
      );
      expect(find.byType(DownloadsEmptyState), findsNothing);
      await shutDown(tester, env);
    });

    haulTest('a filter with no matches says so, without the Add button', (
      tester,
    ) async {
      final env = await boot(tester);
      await seedSnapshot(
        tester,
        env,
        snap('a', DownloadStatus.paused),
        'Compressed',
      );
      cubit<ShellCubit>(tester).filterByStatus(StatusFilter.failed);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Nothing has failed'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DownloadsEmptyState),
          matching: find.text('Add URL'),
        ),
        findsNothing,
      );
      await shutDown(tester, env);
    });

    haulTest('a search with no matches repeats the search', (tester) async {
      final env = await boot(tester);
      await seedSnapshot(
        tester,
        env,
        snap('a', DownloadStatus.paused),
        'Compressed',
      );
      cubit<ShellCubit>(tester).setQuery('zebra');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Nothing matches "zebra"'), findsOneWidget);
      await shutDown(tester, env);
    });

    haulTest('a category with no downloads is named', (tester) async {
      final env = await boot(tester);
      await seedSnapshot(
        tester,
        env,
        snap('a', DownloadStatus.paused),
        'Compressed',
      );
      cubit<ShellCubit>(tester).filterByCategory(env.categoryIds['Music']!);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('No downloads in Music'), findsOneWidget);
      await shutDown(tester, env);
    });
  });

  group('first-run card', () {
    haulTest('a fresh install shows it, with the three steps', (tester) async {
      final env = await boot(tester);
      expect(find.byType(FirstRunCard), findsOneWidget);
      expect(
        find.text('Take over downloads from your browser'),
        findsOneWidget,
      );
      expect(find.textContaining('Install the Haul extension'), findsOneWidget);
      expect(find.textContaining('paste the pairing token'), findsOneWidget);
      expect(find.textContaining('Test connection'), findsOneWidget);
      await shutDown(tester, env);
    });

    haulTest('Dismiss closes it for good', (tester) async {
      final env = await boot(tester);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is HaulIconButton && w.tooltip == 'Dismiss',
        ),
      );
      await settle(tester);
      expect(env.deps.settings.get(Keys.firstRunDismissed), isTrue);
      expect(find.text('Take over downloads from your browser'), findsNothing);
      await shutDown(tester, env);
    });

    haulTest('it stays closed after being dismissed', (tester) async {
      final env = await boot(tester);
      await tester.runAsync(
        () => env.deps.settings.set(Keys.firstRunDismissed, true),
      );
      await settle(tester);
      expect(find.text('Take over downloads from your browser'), findsNothing);
      await shutDown(tester, env);
    });

    haulTest('a connecting browser closes it and remembers', (tester) async {
      final env = await boot(tester);
      expect(find.byType(FirstRunCard), findsOneWidget);
      cubit<BrowserStatusCubit>(tester).connected();
      await settle(tester);
      expect(find.text('Take over downloads from your browser'), findsNothing);
      expect(env.deps.settings.get(Keys.firstRunDismissed), isTrue);
      // It does not come back when the browser goes away.
      cubit<BrowserStatusCubit>(tester).notPaired();
      await settle(tester);
      expect(find.text('Take over downloads from your browser'), findsNothing);
      await shutDown(tester, env);
    });

    haulTest('Copy token puts the pairing token on the clipboard', (
      tester,
    ) async {
      final env = await boot(tester);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(find.text('Copy token'));
      await settle(tester);
      expect(copied, env.deps.settings.get(Keys.bridgeToken));
      expect(copied, hasLength(64));
      await shutDown(tester, env);
    });

    haulTest('Reset all settings does not bring it back', (tester) async {
      final env = await boot(tester);
      await tester.runAsync(
        () => env.deps.settings.set(Keys.firstRunDismissed, true),
      );
      await tester.runAsync(() => env.deps.settings.reset(Keys.all));
      expect(env.deps.settings.get(Keys.firstRunDismissed), isTrue);
      await shutDown(tester, env);
    });
  });

  group('errors on rows', () {
    DownloadSnapshot failed(String id, DownloadErrorCode code) =>
        snap(id, DownloadStatus.failed, error: DownloadError(code, 'x'));

    haulTest('a failed row says why in plain words and has Retry in view', (
      tester,
    ) async {
      final env = await boot(tester);
      await seedSnapshot(
        tester,
        env,
        failed('f', DownloadErrorCode.forbidden),
        'Compressed',
      );
      expect(find.text('The server refused access'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await shutDown(tester, env);
    });

    haulTest('Retry sends the download again', (tester) async {
      final env = await boot(tester);
      await seedSnapshot(
        tester,
        env,
        failed('f', DownloadErrorCode.network),
        'Compressed',
      );
      env.engine.commands.clear();
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(env.engine.commands.whereType<ResumeCommand>().single.id, 'f');
      await shutDown(tester, env);
    });

    haulTest('an expired link offers a new one', (tester) async {
      final env = await boot(tester);
      await seedSnapshot(
        tester,
        env,
        snap('x', DownloadStatus.needsRefresh),
        'Compressed',
      );
      await tester.tap(find.text('New link'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(HaulDialog), findsOneWidget);
      await shutDown(tester, env);
    });

    test('every engine error code reads as plain words', () {
      for (final code in DownloadErrorCode.values) {
        final text = plainError(
          DownloadError(code, 'HTTP 503 detail that must not show'),
        );
        expect(text, isNotEmpty);
        expect(text, isNot(contains('detail')));
        expect(text, isNot(matches(RegExp(r'\d'))), reason: '$code');
        expect(text, isNot(contains('_')));
      }
    });
  });
}
