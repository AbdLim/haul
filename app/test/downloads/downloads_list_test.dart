import 'package:download_engine/download_engine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/app/theme/haul_theme.dart';
import 'package:haul/features/downloads/completion_check.dart';
import 'package:haul/features/downloads/download_row.dart';

import '../support/app_harness.dart';

const mib = 1024 * 1024;

DownloadSnapshot snap(
  String id,
  DownloadStatus status, {
  int? total = 100 * mib,
  int done = 0,
  DownloadError? error,
  bool resumable = true,
}) => DownloadSnapshot(
  request: DownloadRequest(
    id: id,
    url: Uri.parse('https://example.com/$id'),
    saveDir: '/d',
  ),
  status: status,
  fileName: '$id.zip',
  totalBytes: total,
  resumable: resumable,
  error: error,
  segments: [
    if (total != null)
      Segment(id: 0, start: 0, end: total - 1, downloaded: done),
  ],
);

Future<void> addAll(WidgetTester tester, Env env, List<String> ids) async {
  for (final id in ids) {
    await seedSnapshot(
      tester,
      env,
      snap(id, DownloadStatus.paused),
      'Compressed',
    );
  }
}

Future<void> withKey(
  WidgetTester tester,
  LogicalKeyboardKey key,
  Future<void> Function() body,
) async {
  await tester.sendKeyDownEvent(key);
  try {
    await body();
  } finally {
    await tester.sendKeyUpEvent(key);
  }
}

Set<String> selection(WidgetTester tester) =>
    cubit<ShellCubit>(tester).state.selection;

Finder rowFor(String id) =>
    find.ancestor(of: find.text('$id.zip'), matching: find.byType(DownloadRow));

void main() {
  testWidgets('shows a row for each of the seven statuses, in plain words', (
    tester,
  ) async {
    final env = await boot(tester);
    await seedSnapshot(
      tester,
      env,
      snap('q', DownloadStatus.queued),
      'Compressed',
    );
    await seedSnapshot(
      tester,
      env,
      snap('p', DownloadStatus.probing),
      'Compressed',
    );
    await seedSnapshot(
      tester,
      env,
      snap('d', DownloadStatus.downloading, done: 30 * mib),
      'Compressed',
    );
    await seedSnapshot(
      tester,
      env,
      snap('z', DownloadStatus.paused, done: 40 * mib),
      'Compressed',
    );
    await seedSnapshot(
      tester,
      env,
      snap('c', DownloadStatus.completed, done: 100 * mib),
      'Compressed',
    );
    await seedSnapshot(
      tester,
      env,
      snap(
        'f',
        DownloadStatus.failed,
        error: const DownloadError(DownloadErrorCode.notFound, 'HTTP 404'),
      ),
      'Compressed',
    );
    await seedSnapshot(
      tester,
      env,
      snap('r', DownloadStatus.needsRefresh),
      'Compressed',
    );

    for (final id in ['q', 'p', 'd', 'z', 'c', 'f', 'r']) {
      expect(find.text('$id.zip'), findsOneWidget, reason: id);
    }
    expect(find.text('Waiting in the queue'), findsOneWidget);
    expect(find.text('Connecting…'), findsOneWidget);
    expect(find.text('30.0 MB of 100 MB'), findsOneWidget);
    expect(find.text('Paused · 40.0 MB of 100 MB'), findsOneWidget);
    expect(find.text('Completed · 100 MB'), findsOneWidget);
    expect(find.text('The file was not found on the server'), findsOneWidget);
    expect(find.text('Link expired · needs a fresh link'), findsOneWidget);
    expect(find.textContaining('404'), findsNothing);
    await shutDown(tester, env);
  });

  testWidgets('rows are 64 tall and newest first', (tester) async {
    final env = await boot(tester);
    await addAll(tester, env, ['a', 'b', 'c']);
    // The visible card is 64 tall; the row also has 2 points of margin above
    // and below it, which is what spaces the cards 4 apart.
    for (final id in ['a', 'b', 'c']) {
      final card = find.descendant(
        of: rowFor(id),
        matching: find.byType(AnimatedContainer),
      );
      // The animated container's box includes its margin; the decorated
      // box inside it is the card itself.
      final painted = find.descendant(
        of: card.first,
        matching: find.byType(DecoratedBox),
      );
      expect(tester.getSize(painted.first).height, 64, reason: id);
    }
    expect(
      tester.getTopLeft(find.text('b.zip')).dy -
          tester.getTopLeft(find.text('c.zip')).dy,
      68,
    );
    expect(
      tester.getTopLeft(find.text('c.zip')).dy,
      lessThan(tester.getTopLeft(find.text('b.zip')).dy),
    );
    expect(
      tester.getTopLeft(find.text('b.zip')).dy,
      lessThan(tester.getTopLeft(find.text('a.zip')).dy),
    );
    await shutDown(tester, env);
  });

  testWidgets('a running row updates from live progress, with its bar', (
    tester,
  ) async {
    final env = await boot(tester);
    await seedSnapshot(
      tester,
      env,
      snap('d', DownloadStatus.downloading),
      'Compressed',
    );
    env.engine.emit(
      ProgressEvent(
        id: 'd',
        downloadedBytes: 25 * mib,
        totalBytes: 100 * mib,
        bytesPerSecond: 2.0 * mib,
        eta: const Duration(minutes: 1, seconds: 15),
        segmentBytes: const [0],
      ),
    );
    await tester.runAsync(realDelay);
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('25.0 MB of 100 MB · 2.00 MB/s · 1m 15s left'),
      findsOneWidget,
    );
    final bar = tester.widget<HaulProgressBar>(
      find.descendant(of: rowFor('d'), matching: find.byType(HaulProgressBar)),
    );
    expect(bar.value, 0.25);
    expect(bar.active, isTrue);
    await shutDown(tester, env);
  });

  group('selection', () {
    testWidgets('a click selects one row and marks it', (tester) async {
      final env = await boot(tester);
      await addAll(tester, env, ['a', 'b']);
      await tester.tap(find.text('a.zip'));
      await tester.pump();
      expect(selection(tester), {'a'});
      expect(tester.widget<DownloadRow>(rowFor('a')).selected, isTrue);
      expect(tester.widget<DownloadRow>(rowFor('b')).selected, isFalse);

      await tester.tap(find.text('b.zip'));
      await tester.pump();
      expect(selection(tester), {'b'});
      await shutDown(tester, env);
    });

    testWidgets('Command-click adds and removes rows', (tester) async {
      final env = await boot(tester);
      await addAll(tester, env, ['a', 'b', 'c']);
      await tester.tap(find.text('a.zip'));
      await withKey(tester, LogicalKeyboardKey.metaLeft, () async {
        await tester.tap(find.text('c.zip'));
        await tester.pump();
        expect(selection(tester), {'a', 'c'});
        await tester.tap(find.text('a.zip'));
        await tester.pump();
        expect(selection(tester), {'c'});
      });
      await shutDown(tester, env);
    });

    testWidgets('Shift-click selects a range in the order shown', (
      tester,
    ) async {
      final env = await boot(tester);
      await addAll(tester, env, ['a', 'b', 'c', 'd']);
      // Shown newest first: d, c, b, a.
      await tester.tap(find.text('d.zip'));
      await withKey(tester, LogicalKeyboardKey.shiftLeft, () async {
        await tester.tap(find.text('b.zip'));
        await tester.pump();
      });
      expect(selection(tester), {'d', 'c', 'b'});
      await shutDown(tester, env);
    });

    testWidgets('clicking empty space clears the selection', (tester) async {
      final env = await boot(tester);
      await addAll(tester, env, ['a']);
      await tester.tap(find.text('a.zip'));
      await tester.pump();
      expect(selection(tester), isNotEmpty);
      await tester.tapAt(const Offset(800, 700));
      await tester.pump();
      expect(selection(tester), isEmpty);
      await shutDown(tester, env);
    });

    testWidgets('a removed download is dropped from the selection', (
      tester,
    ) async {
      final env = await boot(tester);
      await addAll(tester, env, ['a', 'b']);
      await tester.tap(find.text('a.zip'));
      await tester.pump();
      expect(selection(tester), {'a'});

      env.engine.emit(const RemovedEvent('a'));
      await tester.runAsync(realDelay);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(selection(tester), isEmpty);
      await shutDown(tester, env);
    });
  });

  group('filters', () {
    testWidgets('a status filter narrows the list', (tester) async {
      final env = await boot(tester);
      await seedSnapshot(
        tester,
        env,
        snap('a', DownloadStatus.paused),
        'Compressed',
      );
      await seedSnapshot(
        tester,
        env,
        snap('b', DownloadStatus.completed, done: mib),
        'Compressed',
      );
      cubit<ShellCubit>(tester).filterByStatus(StatusFilter.completed);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('b.zip'), findsOneWidget);
      expect(find.text('a.zip'), findsNothing);
      await shutDown(tester, env);
    });

    testWidgets('a category filter narrows the list', (tester) async {
      final env = await boot(tester);
      await seedSnapshot(
        tester,
        env,
        snap('a', DownloadStatus.paused),
        'Compressed',
      );
      await seedSnapshot(
        tester,
        env,
        snap('b', DownloadStatus.paused),
        'Video',
      );
      cubit<ShellCubit>(tester).filterByCategory(env.categoryIds['Video']!);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('b.zip'), findsOneWidget);
      expect(find.text('a.zip'), findsNothing);
      await shutDown(tester, env);
    });

    testWidgets('typing in search filters as you type', (tester) async {
      final env = await boot(tester);
      await addAll(tester, env, ['alpha', 'beta']);
      await tester.enterText(find.byType(EditableText), 'alp');
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('alpha.zip'), findsOneWidget);
      expect(find.text('beta.zip'), findsNothing);
      await shutDown(tester, env);
    });
  });

  group('hover button', () {
    Finder pauseButton() => find.byWidgetPredicate(
      (w) =>
          w is HaulIconButton &&
          (w.tooltip == 'Pause' || w.tooltip == 'Resume'),
    );

    testWidgets('is hidden until the pointer is over the row', (tester) async {
      final env = await boot(tester);
      await seedSnapshot(
        tester,
        env,
        snap('a', DownloadStatus.downloading),
        'Compressed',
      );
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find
                .descendant(
                  of: rowFor('a'),
                  matching: find.byType(AnimatedOpacity),
                )
                .first,
          )
          .opacity;
      expect(opacity(), 0);

      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: const Offset(-50, -50));
      await g.moveTo(tester.getCenter(find.text('a.zip')));
      await tester.pump();
      expect(opacity(), 1);
      await g.moveTo(const Offset(5, 5));
      await tester.pump();
      expect(opacity(), 0);
      await shutDown(tester, env);
    });

    testWidgets('pauses a running download', (tester) async {
      final env = await boot(tester);
      await seedSnapshot(
        tester,
        env,
        snap('a', DownloadStatus.downloading),
        'Compressed',
      );
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: const Offset(-50, -50));
      await g.moveTo(tester.getCenter(find.text('a.zip')));
      await tester.pump(const Duration(milliseconds: 200));
      env.engine.commands.clear();
      await tester.tap(pauseButton());
      expect(env.engine.commands.whereType<PauseCommand>().single.id, 'a');
      await shutDown(tester, env);
    });

    testWidgets('resumes a paused one', (tester) async {
      final env = await boot(tester);
      await seedSnapshot(
        tester,
        env,
        snap('a', DownloadStatus.paused),
        'Compressed',
      );
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: const Offset(-50, -50));
      await g.moveTo(tester.getCenter(find.text('a.zip')));
      await tester.pump(const Duration(milliseconds: 200));
      env.engine.commands.clear();
      await tester.tap(pauseButton());
      expect(env.engine.commands.whereType<ResumeCommand>().single.id, 'a');
      await shutDown(tester, env);
    });

    testWidgets('a completed or expired row has no pause button', (
      tester,
    ) async {
      final env = await boot(tester);
      await seedSnapshot(
        tester,
        env,
        snap('c', DownloadStatus.completed, done: mib),
        'Compressed',
      );
      await seedSnapshot(
        tester,
        env,
        snap('r', DownloadStatus.needsRefresh),
        'Compressed',
      );
      expect(pauseButton(), findsNothing);
      await shutDown(tester, env);
    });
  });

  group('completion', () {
    testWidgets(
      'a download that finishes draws its check mark and the bar turns green',
      (tester) async {
        final env = await boot(tester);
        await seedSnapshot(
          tester,
          env,
          snap('a', DownloadStatus.downloading, done: 90 * mib),
          'Compressed',
        );
        expect(find.byType(CompletionCheck), findsNothing);

        env.engine.emit(
          SnapshotEvent(snap('a', DownloadStatus.completed, done: 100 * mib)),
        );
        await tester.runAsync(realDelay);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final check = tester.widget<CompletionCheck>(
          find.byType(CompletionCheck),
        );
        expect(check.animate, isTrue);
        final bar = tester.widget<HaulProgressBar>(
          find.descendant(
            of: rowFor('a'),
            matching: find.byType(HaulProgressBar),
          ),
        );
        expect(bar.tone, HaulProgressTone.success);
        expect(bar.value, 1);
        expect(bar.active, isFalse);

        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.hasRunningAnimations, isFalse);
        await shutDown(tester, env);
      },
    );

    testWidgets('a row that was already complete just shows the tick', (
      tester,
    ) async {
      final env = await boot(tester);
      await seedSnapshot(
        tester,
        env,
        snap('a', DownloadStatus.completed, done: 100 * mib),
        'Compressed',
      );
      final check = tester.widget<CompletionCheck>(
        find.byType(CompletionCheck),
      );
      expect(check.animate, isFalse);
      await shutDown(tester, env);
    });

    testWidgets('the check takes 500 ms to draw', (tester) async {
      final env = await boot(tester);
      await seedSnapshot(
        tester,
        env,
        snap('a', DownloadStatus.downloading, done: mib),
        'Compressed',
      );
      env.engine.emit(
        SnapshotEvent(snap('a', DownloadStatus.completed, done: 100 * mib)),
      );
      await tester.runAsync(realDelay);
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 450));
      expect(tester.hasRunningAnimations, isTrue, reason: 'not done at 450 ms');
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.hasRunningAnimations, isFalse);
      await shutDown(tester, env);
    });
  });

  testWidgets('rows come and go with the animation', (tester) async {
    final env = await boot(tester);
    await addAll(tester, env, ['a']);
    await seedSnapshot(
      tester,
      env,
      snap('b', DownloadStatus.paused),
      'Compressed',
    );
    expect(find.text('b.zip'), findsOneWidget);

    env.engine.emit(const RemovedEvent('b'));
    await tester.runAsync(realDelay);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('b.zip'), findsOneWidget, reason: 'still leaving');
    await tester.pumpAndSettle();
    expect(find.text('b.zip'), findsNothing);
    await shutDown(tester, env);
  });

  testWidgets('the tile uses the category icon', (tester) async {
    final env = await boot(tester);
    await seedSnapshot(tester, env, snap('a', DownloadStatus.paused), 'Video');
    final icon = tester.widget<HaulIcon>(
      find.descendant(of: rowFor('a'), matching: find.byType(HaulIcon)).first,
    );
    expect(icon.icon, HaulIcons.video);
    await shutDown(tester, env);
  });

  testWidgets('the list builds the theme colours without errors', (
    tester,
  ) async {
    final env = await boot(tester);
    await addAll(tester, env, ['a']);
    expect(
      HaulTheme.of(tester.element(find.byType(DownloadRow))).colors.accent,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
    await shutDown(tester, env);
  });
}
