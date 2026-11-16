import 'package:download_engine/download_engine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/cubits/shell_cubit.dart';

import '../support/app_harness.dart';
import '../support/test_deps.dart';

const mib = 1024 * 1024;

DownloadSnapshot snap(
  String id,
  DownloadStatus status, {
  int done = 0,
  bool resumable = true,
}) => DownloadSnapshot(
  request: DownloadRequest(
    id: id,
    url: Uri.parse('https://example.com/$id'),
    saveDir: '/downloads',
  ),
  status: status,
  fileName: '$id.zip',
  totalBytes: 100 * mib,
  resumable: resumable,
  segments: [Segment(id: 0, start: 0, end: 100 * mib - 1, downloaded: done)],
);

Future<void> add(
  WidgetTester tester,
  Env env,
  String id,
  DownloadStatus s, {
  int done = 0,
  bool resumable = true,
}) => seedSnapshot(
  tester,
  env,
  snap(id, s, done: done, resumable: resumable),
  'Compressed',
);

FakePlatform platform(Env env) => env.deps.platform as FakePlatform;
Set<String> selection(WidgetTester tester) =>
    cubit<ShellCubit>(tester).state.selection;

/// Enough frames for a menu or dialog to finish opening or closing. Not
/// `pumpAndSettle`: a running download's progress bar animates for ever.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> rightClick(WidgetTester tester, String id) async {
  final g = await tester.startGesture(
    tester.getCenter(find.text('$id.zip')),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await g.up();
  await settle(tester);
}

/// An item of the open menu, not the same words elsewhere (the detail panel
/// has buttons with the same names).
Finder menuItem(String label) =>
    find.descendant(of: find.byKey(haulMenuKey), matching: find.text(label));

Future<void> choose(WidgetTester tester, String label) async {
  await tester.tap(menuItem(label));
  await settle(tester);
}

/// Presses a button of the open dialog (the detail panel can have a button
/// with the same name, so only the dialog is searched).
Future<void> confirmWith(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(HaulDialog), matching: find.text(label)),
  );
  await settle(tester);
  await tester.runAsync(() => realDelay(60));
  await tester.pump();
}

/// What the app puts on the clipboard.
List<String> watchClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
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
  return copied;
}

void main() {
  group('the right-click menu', () {
    testWidgets('right-clicking a row selects it and opens the menu', (
      tester,
    ) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.paused);
      await add(tester, env, 'b', DownloadStatus.paused);
      await rightClick(tester, 'a');
      expect(selection(tester), {'a'});
      expect(menuItem('Resume'), findsOneWidget);
      expect(menuItem('Remove from list'), findsOneWidget);
      await shutDown(tester, env);
    });

    testWidgets('right-clicking inside a selection keeps the whole selection', (
      tester,
    ) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.paused);
      await add(tester, env, 'b', DownloadStatus.paused);
      cubit<ShellCubit>(tester).select({'a', 'b'});
      await tester.pump();
      await rightClick(tester, 'a');
      expect(selection(tester), {'a', 'b'});
      await shutDown(tester, env);
    });

    testWidgets('the menu shows only what fits the status', (tester) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.downloading, done: 10 * mib);
      await rightClick(tester, 'a');
      expect(menuItem('Pause'), findsOneWidget);
      expect(menuItem('Resume'), findsNothing);
      expect(menuItem('Open'), findsNothing);
      expect(menuItem('Delete file…'), findsNothing);
      await shutDown(tester, env);
    });
  });

  group('actions', () {
    testWidgets('Pause sends the command', (tester) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.downloading, done: mib);
      env.engine.commands.clear();
      await rightClick(tester, 'a');
      await choose(tester, 'Pause');
      expect(env.engine.commands.whereType<PauseCommand>().single.id, 'a');
      await shutDown(tester, env);
    });

    testWidgets('Resume and Retry send resume', (tester) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.paused);
      await add(tester, env, 'b', DownloadStatus.failed);
      env.engine.commands.clear();
      await rightClick(tester, 'a');
      await choose(tester, 'Resume');
      await rightClick(tester, 'b');
      await choose(tester, 'Retry');
      final ids = env.engine.commands.whereType<ResumeCommand>().map(
        (c) => c.id,
      );
      expect(ids, ['a', 'b']);
      await shutDown(tester, env);
    });

    testWidgets('Show in Finder reveals the folder of an unfinished download', (
      tester,
    ) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.paused);
      await rightClick(tester, 'a');
      await choose(tester, 'Show in Finder');
      expect(platform(env).revealed, ['/downloads']);
      await shutDown(tester, env);
    });

    testWidgets('Show in Finder reveals the file itself once it is complete', (
      tester,
    ) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.completed, done: 100 * mib);
      await rightClick(tester, 'a');
      await choose(tester, 'Show in Finder');
      expect(platform(env).revealed, ['/downloads/a.zip']);
      await shutDown(tester, env);
    });

    testWidgets('Open opens a completed file', (tester) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.completed, done: 100 * mib);
      await rightClick(tester, 'a');
      await choose(tester, 'Open');
      expect(platform(env).opened, ['/downloads/a.zip']);
      await shutDown(tester, env);
    });

    testWidgets('Copy URL puts the link on the clipboard', (tester) async {
      final env = await boot(tester);
      final copied = watchClipboard(tester);
      await add(tester, env, 'a', DownloadStatus.paused);
      await rightClick(tester, 'a');
      await choose(tester, 'Copy URL');
      expect(copied, ['https://example.com/a']);
      await shutDown(tester, env);
    });

    testWidgets('Copy URL for several puts one link per line', (tester) async {
      final env = await boot(tester);
      final copied = watchClipboard(tester);
      await add(tester, env, 'a', DownloadStatus.paused);
      await add(tester, env, 'b', DownloadStatus.paused);
      cubit<ShellCubit>(tester).select({'a', 'b'});
      await tester.pump();
      await rightClick(tester, 'a');
      await choose(tester, 'Copy URL');
      expect(copied.single.split('\n').toSet(), {
        'https://example.com/a',
        'https://example.com/b',
      });
      await shutDown(tester, env);
    });

    testWidgets('Remove from list removes without confirming', (tester) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.completed, done: 100 * mib);
      env.engine.commands.clear();
      await rightClick(tester, 'a');
      await choose(tester, 'Remove from list');
      expect(env.engine.commands.whereType<RemoveCommand>().single.id, 'a');
      expect(platform(env).trashed, isEmpty, reason: 'the file stays');
      await shutDown(tester, env);
    });

    testWidgets('Refresh link asks for a new link and sends it', (
      tester,
    ) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.needsRefresh, done: 30 * mib);
      env.engine.commands.clear();
      await rightClick(tester, 'a');
      await choose(tester, 'Refresh link…');
      expect(find.text('Refresh the link'), findsOneWidget);

      await tester.enterText(
        find.byType(EditableText).last,
        'https://example.com/a?sig=new',
      );
      await confirmWith(tester, 'Refresh');
      final cmd = env.engine.commands.whereType<RefreshUrlCommand>().single;
      expect(cmd.id, 'a');
      expect(cmd.url, Uri.parse('https://example.com/a?sig=new'));
      await shutDown(tester, env);
    });

    testWidgets('Refresh link refuses a bad link', (tester) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.needsRefresh);
      env.engine.commands.clear();
      await rightClick(tester, 'a');
      await choose(tester, 'Refresh link…');
      await tester.enterText(find.byType(EditableText).last, 'nonsense');
      await tester.tap(find.text('Refresh'));
      await tester.pump();
      expect(find.text('That does not look like a link'), findsOneWidget);
      expect(env.engine.commands.whereType<RefreshUrlCommand>(), isEmpty);
      await shutDown(tester, env);
    });
  });

  group('confirmations', () {
    testWidgets('Cancel asks first, and sends cancel only when confirmed', (
      tester,
    ) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.paused, done: mib);
      env.engine.commands.clear();
      await rightClick(tester, 'a');
      await choose(tester, 'Cancel download…');
      expect(
        find.text('Cancel 1 download?'.replaceFirst('1 download', 'download')),
        findsOneWidget,
      );
      expect(env.engine.commands.whereType<CancelCommand>(), isEmpty);

      await confirmWith(tester, 'Cancel download');
      expect(env.engine.commands.whereType<CancelCommand>().single.id, 'a');
      await shutDown(tester, env);
    });

    testWidgets('declining a cancel does nothing', (tester) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.paused, done: mib);
      env.engine.commands.clear();
      await rightClick(tester, 'a');
      await choose(tester, 'Cancel download…');
      await confirmWith(tester, 'Keep');
      expect(env.engine.commands.whereType<CancelCommand>(), isEmpty);
      await shutDown(tester, env);
    });

    testWidgets('Escape declines a confirmation', (tester) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.paused, done: mib);
      env.engine.commands.clear();
      await rightClick(tester, 'a');
      await choose(tester, 'Cancel download…');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(env.engine.commands.whereType<CancelCommand>(), isEmpty);
      await shutDown(tester, env);
    });

    testWidgets('cancelling several says how many', (tester) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.paused);
      await add(tester, env, 'b', DownloadStatus.paused);
      cubit<ShellCubit>(tester).select({'a', 'b'});
      await tester.pump();
      await rightClick(tester, 'a');
      await choose(tester, 'Cancel download…');
      expect(find.text('Cancel 2 downloads?'), findsOneWidget);
      env.engine.commands.clear();
      await confirmWith(tester, 'Cancel download');
      expect(env.engine.commands.whereType<CancelCommand>(), hasLength(2));
      await shutDown(tester, env);
    });

    testWidgets('Delete file asks, then moves it to the Trash and removes it', (
      tester,
    ) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.completed, done: 100 * mib);
      env.engine.commands.clear();
      await rightClick(tester, 'a');
      await choose(tester, 'Delete file…');
      expect(find.text('Delete file?'), findsOneWidget);
      expect(platform(env).trashed, isEmpty, reason: 'not before confirming');

      await confirmWith(tester, 'Move to Trash');
      expect(platform(env).trashed, ['/downloads/a.zip']);
      expect(env.engine.commands.whereType<RemoveCommand>().single.id, 'a');
      await shutDown(tester, env);
    });

    testWidgets('declining Delete file leaves everything alone', (
      tester,
    ) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.completed, done: 100 * mib);
      env.engine.commands.clear();
      await rightClick(tester, 'a');
      await choose(tester, 'Delete file…');
      await confirmWith(tester, 'Keep');
      expect(platform(env).trashed, isEmpty);
      expect(env.engine.commands.whereType<RemoveCommand>(), isEmpty);
      await shutDown(tester, env);
    });
  });

  group('pausing a download that cannot resume', () {
    testWidgets('warns that it will start over, and pauses only if confirmed', (
      tester,
    ) async {
      final env = await boot(tester);
      await add(
        tester,
        env,
        'a',
        DownloadStatus.downloading,
        done: 40 * mib,
        resumable: false,
      );
      env.engine.commands.clear();
      await rightClick(tester, 'a');
      await choose(tester, 'Pause');
      expect(find.text('Pause and start over?'), findsOneWidget);
      expect(env.engine.commands.whereType<PauseCommand>(), isEmpty);

      await confirmWith(tester, 'Pause anyway');
      expect(env.engine.commands.whereType<PauseCommand>().single.id, 'a');
      await shutDown(tester, env);
    });

    testWidgets('"Keep downloading" does not pause', (tester) async {
      final env = await boot(tester);
      await add(
        tester,
        env,
        'a',
        DownloadStatus.downloading,
        done: 40 * mib,
        resumable: false,
      );
      env.engine.commands.clear();
      await rightClick(tester, 'a');
      await choose(tester, 'Pause');
      await confirmWith(tester, 'Keep downloading');
      expect(env.engine.commands.whereType<PauseCommand>(), isEmpty);
      await shutDown(tester, env);
    });

    testWidgets('a resumable download pauses at once, with no warning', (
      tester,
    ) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.downloading, done: 40 * mib);
      env.engine.commands.clear();
      await rightClick(tester, 'a');
      await choose(tester, 'Pause');
      expect(find.text('Pause and start over?'), findsNothing);
      expect(env.engine.commands.whereType<PauseCommand>(), hasLength(1));
      await shutDown(tester, env);
    });

    testWidgets(
      'a download that has not started yet pauses without a warning',
      (tester) async {
        final env = await boot(tester);
        await add(
          tester,
          env,
          'a',
          DownloadStatus.downloading,
          done: 0,
          resumable: false,
        );
        env.engine.commands.clear();
        await rightClick(tester, 'a');
        await choose(tester, 'Pause');
        expect(find.text('Pause and start over?'), findsNothing);
        expect(env.engine.commands.whereType<PauseCommand>(), hasLength(1));
        await shutDown(tester, env);
      },
    );
  });

  group('several downloads at once', () {
    testWidgets('Pause applies only to those that are running', (tester) async {
      final env = await boot(tester);
      await add(tester, env, 'run1', DownloadStatus.downloading, done: mib);
      await add(tester, env, 'run2', DownloadStatus.downloading, done: mib);
      await add(tester, env, 'hold', DownloadStatus.paused);
      cubit<ShellCubit>(tester).select({'run1', 'run2', 'hold'});
      await tester.pump();
      env.engine.commands.clear();
      await rightClick(tester, 'run1');
      await choose(tester, 'Pause');
      expect(
        env.engine.commands.whereType<PauseCommand>().map((c) => c.id).toSet(),
        {'run1', 'run2'},
      );
      await shutDown(tester, env);
    });
  });

  group('keyboard', () {
    testWidgets('Space pauses a running selection', (tester) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.downloading, done: mib);
      await tester.tap(find.text('a.zip'));
      await tester.pump();
      env.engine.commands.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);
      expect(env.engine.commands.whereType<PauseCommand>().single.id, 'a');
      await shutDown(tester, env);
    });

    testWidgets('Space resumes a paused selection', (tester) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.paused);
      await tester.tap(find.text('a.zip'));
      await tester.pump();
      env.engine.commands.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);
      expect(env.engine.commands.whereType<ResumeCommand>().single.id, 'a');
      await shutDown(tester, env);
    });

    testWidgets('Delete removes the selection from the list', (tester) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.completed, done: 100 * mib);
      await tester.tap(find.text('a.zip'));
      await tester.pump();
      env.engine.commands.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await settle(tester);
      expect(env.engine.commands.whereType<RemoveCommand>().single.id, 'a');
      expect(platform(env).trashed, isEmpty);
      await shutDown(tester, env);
    });

    testWidgets('Delete does not remove a download that is running', (
      tester,
    ) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.downloading, done: mib);
      await tester.tap(find.text('a.zip'));
      await tester.pump();
      env.engine.commands.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await settle(tester);
      expect(env.engine.commands.whereType<RemoveCommand>(), isEmpty);
      await shutDown(tester, env);
    });

    testWidgets('Escape clears the selection', (tester) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.paused);
      await tester.tap(find.text('a.zip'));
      await tester.pump();
      expect(selection(tester), {'a'});
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(selection(tester), isEmpty);
      await shutDown(tester, env);
    });

    testWidgets('Space in the search box types a space and pauses nothing', (
      tester,
    ) async {
      final env = await boot(tester);
      await add(tester, env, 'a', DownloadStatus.downloading, done: mib);
      await tester.tap(find.text('a.zip'));
      await tester.pump();
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      env.engine.commands.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(env.engine.commands.whereType<PauseCommand>(), isEmpty);
      await shutDown(tester, env);
    });
  });

  testWidgets(
    'the hover button also warns before pausing a download that cannot resume',
    (tester) async {
      final env = await boot(tester);
      await add(
        tester,
        env,
        'a',
        DownloadStatus.downloading,
        done: 40 * mib,
        resumable: false,
      );
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: const Offset(-50, -50));
      await g.moveTo(tester.getCenter(find.text('a.zip')));
      await tester.pump(const Duration(milliseconds: 200));
      env.engine.commands.clear();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is HaulIconButton && w.tooltip == 'Pause',
        ),
      );
      await settle(tester);
      expect(find.text('Pause and start over?'), findsOneWidget);
      expect(env.engine.commands.whereType<PauseCommand>(), isEmpty);
      await shutDown(tester, env);
    },
  );
}
