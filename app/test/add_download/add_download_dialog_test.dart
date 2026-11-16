import 'package:download_engine/download_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/features/header/header_band.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/features/add_download/add_download_dialog.dart';
import 'package:haul/services/network/url_prober.dart';

import '../support/app_harness.dart';
import '../support/test_deps.dart';

/// The header's button; the empty list has one of its own.
final headerAddUrl = find.descendant(
  of: find.byType(HeaderBand),
  matching: find.text('Add URL'),
);

const mib = 1024 * 1024;

FakeUrlProber prober(Env env) => env.deps.urlProber as FakeUrlProber;
FakeFolderPicker picker(Env env) => env.deps.folderPicker as FakeFolderPicker;

Future<void> openDialog(WidgetTester tester, {String? url}) async {
  cubit<ShellCubit>(tester).openAddDialog(url: url);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> type(WidgetTester tester, String label, String text) async {
  final field = find.byWidgetPredicate(
    (w) => w is HaulTextField && w.semanticLabel == label,
  );
  await tester.enterText(
    find.descendant(of: field, matching: find.byType(EditableText)),
    text,
  );
  await tester.pump();
}

/// Lets the 400 ms pause in typing pass so the link gets looked at. Both
/// clocks are advanced: a link typed in the field uses the fake one, while a
/// link handed to the dialog on opening uses the real one.
Future<void> afterTyping(WidgetTester tester) async {
  await tester.runAsync(() => realDelay(480));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

/// After the dialog has gone, lets the host's clean-up (which runs once the
/// route's future completes) finish.
Future<void> afterClosing(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() => realDelay(80));
  await tester.pump();
}

/// A tap that starts database work, so it has to run in the real zone.
Future<void> tapReal(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await realDelay(200);
  });
  // Two frames for the list to take the new row, then its entrance.
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Finder dialog() => find.byType(AddDownloadDialog);

void main() {
  testWidgets('opens from the shell with its fields, Cancel and Start', (
    tester,
  ) async {
    final env = await boot(tester);
    await openDialog(tester);
    expect(find.text('Add a download'), findsOneWidget);
    for (final t in [
      'Link',
      'File name',
      'Category',
      'Connections',
      'Save to',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Choose…'), findsOneWidget);
    await shutDown(tester, env);
  });

  testWidgets('the Add URL button in the header opens it', (tester) async {
    final env = await boot(tester);
    await tester.tap(headerAddUrl);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(dialog(), findsOneWidget);
    await shutDown(tester, env);
  });

  testWidgets('a link handed over from elsewhere is filled in and looked at', (
    tester,
  ) async {
    final env = await boot(tester);
    prober(env).answers['https://a.com/dl.zip'] = const UrlInfo(
      fileName: 'dl.zip',
      size: 5 * mib,
      supportsRanges: true,
    );
    await openDialog(tester, url: 'https://a.com/dl.zip');
    await afterTyping(tester);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byWidgetPredicate(
                (w) => w is HaulTextField && w.semanticLabel == 'Link',
              ),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'https://a.com/dl.zip',
    );
    expect(find.text('dl.zip · 5.00 MB'), findsOneWidget);
    await shutDown(tester, env);
  });

  testWidgets('an empty link is refused inline', (tester) async {
    final env = await boot(tester);
    await openDialog(tester);
    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(find.text('Enter a link to download'), findsOneWidget);
    expect(dialog(), findsOneWidget, reason: 'stays open');
    expect(env.engine.commands.whereType<AddCommand>(), isEmpty);
    await shutDown(tester, env);
  });

  testWidgets('a link that is not http or https is refused inline', (
    tester,
  ) async {
    final env = await boot(tester);
    await openDialog(tester);
    await type(tester, 'Link', 'ftp://a.com/file.zip');
    expect(find.text('Only http and https links work'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(dialog(), findsOneWidget);
    expect(env.engine.commands.whereType<AddCommand>(), isEmpty);
    expect(prober(env).calls, isEmpty);
    await shutDown(tester, env);
  });

  testWidgets('text that is not a link is refused inline', (tester) async {
    final env = await boot(tester);
    await openDialog(tester);
    await type(tester, 'Link', 'hello there');
    expect(find.text('That does not look like a link'), findsOneWidget);
    await shutDown(tester, env);
  });

  testWidgets('the probe result shows the detected name and size', (
    tester,
  ) async {
    final env = await boot(tester);
    prober(env).answers['https://a.com/get?id=7'] = const UrlInfo(
      fileName: 'ubuntu-24.iso',
      size: 6 * 1024 * mib,
      supportsRanges: true,
    );
    await openDialog(tester);
    await type(tester, 'Link', 'https://a.com/get?id=7');
    expect(find.text('Checking the link…'), findsOneWidget);
    await afterTyping(tester);
    expect(find.text('ubuntu-24.iso · 6.00 GB'), findsOneWidget);
    await shutDown(tester, env);
  });

  testWidgets('a server that cannot resume is mentioned', (tester) async {
    final env = await boot(tester);
    prober(env).answers['https://a.com/f.bin'] = const UrlInfo(
      fileName: 'f.bin',
      size: mib,
      supportsRanges: false,
    );
    await openDialog(tester);
    await type(tester, 'Link', 'https://a.com/f.bin');
    await afterTyping(tester);
    expect(
      find.textContaining('cannot be resumed once paused'),
      findsOneWidget,
    );
    await shutDown(tester, env);
  });

  testWidgets('a probe that fails says so in words', (tester) async {
    final env = await boot(tester);
    prober(env).failures['https://a.com/gone'] =
        'The file was not found on the server';
    await openDialog(tester);
    await type(tester, 'Link', 'https://a.com/gone');
    await afterTyping(tester);
    expect(find.text('The file was not found on the server'), findsOneWidget);
    await shutDown(tester, env);
  });

  testWidgets('the detected name picks the category and shows its folder', (
    tester,
  ) async {
    final env = await boot(tester);
    prober(env).answers['https://a.com/m'] = const UrlInfo(
      fileName: 'movie.mp4',
      supportsRanges: true,
    );
    await openDialog(tester);
    expect(find.text('/Users/test/Downloads'), findsOneWidget);
    await type(tester, 'Link', 'https://a.com/m');
    await afterTyping(tester);
    expect(find.text('Video'), findsWidgets);
    expect(find.text('/Users/test/Downloads/Video'), findsOneWidget);
    await shutDown(tester, env);
  });

  testWidgets('choosing a category changes the folder', (tester) async {
    final env = await boot(tester);
    await openDialog(tester);
    await tester.tap(find.byType(HaulDropdown<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Music').last);
    await tester.pumpAndSettle();
    expect(find.text('/Users/test/Downloads/Music'), findsOneWidget);
    await shutDown(tester, env);
  });

  testWidgets('Choose… picks a folder and shows it', (tester) async {
    final env = await boot(tester);
    picker(env).next = '/Volumes/Big/Stuff';
    await openDialog(tester);
    await tester.tap(find.text('Choose…'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('/Volumes/Big/Stuff'), findsOneWidget);
    await shutDown(tester, env);
  });

  testWidgets('long folder paths keep their end', (tester) async {
    expect(
      shortenPath(
        '/Users/someone/Documents/Projects/Archive/2026/Downloads/Video',
      ),
      startsWith('…'),
    );
    expect(
      shortenPath(
        '/Users/someone/Documents/Projects/Archive/2026/Downloads/Video',
      ),
      endsWith('Downloads/Video'),
    );
    expect(shortenPath('/short/path'), '/short/path');
  });

  testWidgets('Start adds the download to the chosen folder and closes', (
    tester,
  ) async {
    final env = await boot(tester);
    prober(env).answers['https://a.com/m.mp4'] = const UrlInfo(
      fileName: 'm.mp4',
      supportsRanges: true,
    );
    await openDialog(tester);
    await type(tester, 'Link', 'https://a.com/m.mp4');
    await afterTyping(tester);
    env.engine.commands.clear();

    await tapReal(tester, find.text('Start'));

    final add = env.engine.commands.whereType<AddCommand>().single;
    expect(add.request.url, Uri.parse('https://a.com/m.mp4'));
    expect(add.request.saveDir, '/Users/test/Downloads/Video');
    expect(add.request.maxConnections, 8);
    expect(dialog(), findsNothing, reason: 'closed');
    expect(cubit<ShellCubit>(tester).state.addDialogOpen, isFalse);
    // And it is in the list.
    expect(find.text('m.mp4'), findsOneWidget);
    await shutDown(tester, env);
  });

  testWidgets('Enter in the link field starts it too', (tester) async {
    final env = await boot(tester);
    await openDialog(tester);
    await type(tester, 'Link', 'https://a.com/enter.bin');
    env.engine.commands.clear();
    await tester.runAsync(() async {
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await realDelay(200);
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(env.engine.commands.whereType<AddCommand>(), hasLength(1));
    expect(dialog(), findsNothing);
    await shutDown(tester, env);
  });

  testWidgets('a typed file name and a connection count are passed on', (
    tester,
  ) async {
    final env = await boot(tester);
    await openDialog(tester);
    await type(tester, 'Link', 'https://a.com/x');
    await type(tester, 'File name', 'mine.bin');
    await tester.tap(find.byType(HaulDropdown<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2').last);
    await tester.pumpAndSettle();
    env.engine.commands.clear();
    await tapReal(tester, find.text('Start'));
    final add = env.engine.commands.whereType<AddCommand>().single;
    expect(add.request.fileName, 'mine.bin');
    expect(add.request.maxConnections, 2);
    await shutDown(tester, env);
  });

  testWidgets('connections start at the setting', (tester) async {
    final env = await boot(tester);
    await tester.runAsync(() => env.deps.settings.set(Keys.maxConnections, 4));
    await openDialog(tester);
    final dropdown = tester.widget<HaulDropdown<int>>(
      find.byType(HaulDropdown<int>).last,
    );
    expect(dropdown.value, 4);
    await shutDown(tester, env);
  });

  testWidgets('Cancel closes without adding anything', (tester) async {
    final env = await boot(tester);
    await openDialog(tester);
    await type(tester, 'Link', 'https://a.com/x');
    env.engine.commands.clear();
    await tester.tap(find.text('Cancel'));
    await afterClosing(tester);
    expect(dialog(), findsNothing);
    expect(env.engine.commands.whereType<AddCommand>(), isEmpty);
    expect(cubit<ShellCubit>(tester).state.addDialogOpen, isFalse);
    await shutDown(tester, env);
  });

  testWidgets('Escape closes it and it can be opened again', (tester) async {
    final env = await boot(tester);
    await openDialog(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await afterClosing(tester);
    expect(dialog(), findsNothing);
    await openDialog(tester);
    expect(dialog(), findsOneWidget);
    await shutDown(tester, env);
  });

  group('a link already in the list', () {
    Future<void> addExisting(WidgetTester tester, Env env) async {
      final request = DownloadRequest(
        id: 'old',
        url: Uri.parse('https://a.com/dup.zip'),
        saveDir: '/d',
      );
      await seedSnapshot(
        tester,
        env,
        DownloadSnapshot(
          request: request,
          status: DownloadStatus.paused,
          fileName: 'dup.zip',
        ),
        'Compressed',
      );
      env.engine.commands.clear();
    }

    testWidgets('by default it asks, and nothing is added yet', (tester) async {
      final env = await boot(tester);
      await addExisting(tester, env);
      await openDialog(tester);
      await type(tester, 'Link', 'https://a.com/dup.zip');
      await tapReal(tester, find.text('Start'));
      expect(find.text('This link is already in your list.'), findsOneWidget);
      expect(find.text('Add a copy'), findsOneWidget);
      expect(find.text('Resume existing'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(env.engine.commands.whereType<AddCommand>(), isEmpty);
      await shutDown(tester, env);
    });

    testWidgets('Add a copy adds it', (tester) async {
      final env = await boot(tester);
      await addExisting(tester, env);
      await openDialog(tester);
      await type(tester, 'Link', 'https://a.com/dup.zip');
      await tapReal(tester, find.text('Start'));
      await tapReal(tester, find.text('Add a copy'));
      expect(env.engine.commands.whereType<AddCommand>(), hasLength(1));
      expect(dialog(), findsNothing);
      await shutDown(tester, env);
    });

    testWidgets('Resume existing resumes the old one', (tester) async {
      final env = await boot(tester);
      await addExisting(tester, env);
      await openDialog(tester);
      await type(tester, 'Link', 'https://a.com/dup.zip');
      await tapReal(tester, find.text('Start'));
      await tapReal(tester, find.text('Resume existing'));
      expect(env.engine.commands.whereType<ResumeCommand>().single.id, 'old');
      expect(env.engine.commands.whereType<AddCommand>(), isEmpty);
      expect(dialog(), findsNothing);
      await shutDown(tester, env);
    });

    testWidgets('with the setting on "numbered copy" it just adds', (
      tester,
    ) async {
      final env = await boot(tester);
      await tester.runAsync(
        () => env.deps.settings.set(
          Keys.duplicateAction,
          DuplicateAction.numberedCopy,
        ),
      );
      await addExisting(tester, env);
      await openDialog(tester);
      await type(tester, 'Link', 'https://a.com/dup.zip');
      await tapReal(tester, find.text('Start'));
      expect(env.engine.commands.whereType<AddCommand>(), hasLength(1));
      expect(find.text('This link is already in your list.'), findsNothing);
      await shutDown(tester, env);
    });

    testWidgets('with the setting on "resume existing" it resumes at once', (
      tester,
    ) async {
      final env = await boot(tester);
      await tester.runAsync(
        () => env.deps.settings.set(
          Keys.duplicateAction,
          DuplicateAction.resumeExisting,
        ),
      );
      await addExisting(tester, env);
      await openDialog(tester);
      await type(tester, 'Link', 'https://a.com/dup.zip');
      await tapReal(tester, find.text('Start'));
      expect(env.engine.commands.whereType<ResumeCommand>(), hasLength(1));
      expect(dialog(), findsNothing);
      await shutDown(tester, env);
    });
  });
}
