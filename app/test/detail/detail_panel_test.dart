import 'package:download_engine/download_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/features/detail/detail_panel.dart';
import 'package:haul/features/detail/segment_map.dart';
import 'package:haul/features/shell/shell_metrics.dart';

import '../support/app_harness.dart';

const mib = 1024 * 1024;

List<Segment> segs(int n, {int each = 100, int downloaded = 0}) => [
  for (var i = 0; i < n; i++)
    Segment(
      id: i,
      start: i * each,
      end: i * each + each - 1,
      downloaded: downloaded,
    ),
];

DownloadSnapshot snap(
  String id,
  DownloadStatus status, {
  List<Segment>? segments,
  DownloadError? error,
}) => DownloadSnapshot(
  request: DownloadRequest(
    id: id,
    url: Uri.parse('https://example.com/files/$id?token=abc'),
    saveDir: '/Users/test/Downloads/Compressed',
  ),
  status: status,
  fileName: '$id.zip',
  totalBytes: 800,
  segments: segments ?? segs(8),
  error: error,
);

Future<void> add(WidgetTester tester, Env env, DownloadSnapshot s) =>
    seedSnapshot(tester, env, s, 'Compressed');

Future<void> live(
  WidgetTester tester,
  Env env,
  String id,
  List<Segment> segments, {
  double speed = 0,
}) async {
  env.engine.emit(
    ProgressEvent(
      id: id,
      downloadedBytes: segments.fold(0, (n, s) => n + s.downloaded),
      totalBytes: 800,
      bytesPerSecond: speed,
      segmentBytes: [for (final s in segments) s.downloaded],
      segments: segments,
    ),
  );
  await tester.runAsync(() => realDelay(60));
  await tester.pump();
}

/// Frames for the panel to finish moving, without `pumpAndSettle` (a running
/// download's bar never stops animating).
Future<void> settle(WidgetTester tester, [int ms = 400]) async {
  // The first frame takes the cubit's change, the second starts the
  // animation, the third lets it run.
  await tester.pump();
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

double panelWidth(WidgetTester tester) {
  final clip = find.descendant(
    of: find.byType(DetailPanelHost),
    matching: find.byType(ClipRect),
  );
  return clip.evaluate().isEmpty ? 0 : tester.getSize(clip.first).width;
}

void main() {
  testWidgets('there is no panel until a download is selected', (tester) async {
    final env = await boot(tester);
    await add(tester, env, snap('a', DownloadStatus.paused));
    expect(find.byType(DetailPanel), findsNothing);
    expect(panelWidth(tester), 0);
    await shutDown(tester, env);
  });

  testWidgets(
    'selecting one download slides the panel in, 340 wide, over 260 ms',
    (tester) async {
      final env = await boot(tester);
      await add(tester, env, snap('a', DownloadStatus.paused));
      await tester.tap(find.text('a.zip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final early = panelWidth(tester);
      expect(early, greaterThan(0));
      expect(early, lessThan(ShellMetrics.detailWidth));

      await tester.pump(const Duration(milliseconds: 100));
      final mid = panelWidth(tester);
      expect(mid, greaterThan(early));
      expect(mid, lessThan(ShellMetrics.detailWidth));

      await tester.pump(const Duration(milliseconds: 250));
      expect(panelWidth(tester), ShellMetrics.detailWidth);
      await shutDown(tester, env);
    },
  );

  testWidgets('the panel sits at the right edge, the full height', (
    tester,
  ) async {
    final env = await boot(tester);
    await add(tester, env, snap('a', DownloadStatus.paused));
    await tester.tap(find.text('a.zip'));
    await settle(tester);
    final rect = tester.getRect(find.byType(DetailPanel));
    expect(rect.right, 1200);
    expect(rect.width, ShellMetrics.detailWidth);
    expect(rect.top, 0);
    expect(rect.height, 800);
    await shutDown(tester, env);
  });

  testWidgets('it fades as it slides', (tester) async {
    final env = await boot(tester);
    await add(tester, env, snap('a', DownloadStatus.paused));
    await tester.tap(find.text('a.zip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final opacity = tester.widget<Opacity>(
      find
          .descendant(
            of: find.byType(DetailPanelHost),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(opacity.opacity, inExclusiveRange(0, 1));
    await shutDown(tester, env);
  });

  testWidgets('it shows the name, link, save path and state', (tester) async {
    final env = await boot(tester);
    await add(tester, env, snap('movie', DownloadStatus.paused));
    await tester.tap(find.text('movie.zip'));
    await settle(tester);
    final panel = find.byType(DetailPanel);
    expect(
      find.descendant(of: panel, matching: find.text('movie.zip')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: panel,
        matching: find.text('https://example.com/files/movie?token=abc'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: panel,
        matching: find.text('/Users/test/Downloads/Compressed/movie.zip'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.text('Segments')),
      findsOneWidget,
    );
    await shutDown(tester, env);
  });

  testWidgets('a failed download shows the problem in plain words', (
    tester,
  ) async {
    final env = await boot(tester);
    await add(
      tester,
      env,
      snap(
        'bad',
        DownloadStatus.failed,
        error: const DownloadError(DownloadErrorCode.diskFull, 'ENOSPC'),
      ),
    );
    await tester.tap(find.text('bad.zip'));
    await settle(tester);
    final panel = find.byType(DetailPanel);
    expect(
      find.descendant(of: panel, matching: find.text('Problem')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.text('The disk is full')),
      findsOneWidget,
    );
    expect(find.textContaining('ENOSPC'), findsNothing);
    await shutDown(tester, env);
  });

  testWidgets('a download with no problem shows no problem section', (
    tester,
  ) async {
    final env = await boot(tester);
    await add(tester, env, snap('a', DownloadStatus.paused));
    await tester.tap(find.text('a.zip'));
    await settle(tester);
    expect(find.text('Problem'), findsNothing);
    await shutDown(tester, env);
  });

  group('the segment map', () {
    testWidgets('describes the connections it shows', (tester) async {
      final env = await boot(tester);
      await add(
        tester,
        env,
        snap('a', DownloadStatus.paused, segments: segs(8, downloaded: 100)),
      );
      await tester.tap(find.text('a.zip'));
      await settle(tester);
      expect(find.byType(SegmentMap), findsOneWidget);
      expect(find.text('8 connections · 8 done'), findsOneWidget);
      await shutDown(tester, env);
    });

    testWidgets('says so when nothing has started', (tester) async {
      final env = await boot(tester);
      await add(
        tester,
        env,
        snap('a', DownloadStatus.queued, segments: const []),
      );
      await tester.tap(find.text('a.zip'));
      await settle(tester);
      expect(find.text('Not started yet'), findsOneWidget);
      expect(find.byType(SegmentMap), findsNothing);
      await shutDown(tester, env);
    });

    testWidgets('follows live progress while downloading', (tester) async {
      final env = await boot(tester);
      await add(tester, env, snap('a', DownloadStatus.downloading));
      await tester.tap(find.text('a.zip'));
      await settle(tester);
      expect(find.text('8 connections · 0 done'), findsOneWidget);

      await live(tester, env, 'a', segs(8, downloaded: 100));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('8 connections · 8 done'), findsOneWidget);
      await shutDown(tester, env);
    });

    testWidgets(
      'a split shows one more block, and the block divides over 250 ms',
      (tester) async {
        final env = await boot(tester);
        await add(
          tester,
          env,
          snap('a', DownloadStatus.downloading, segments: segs(4, each: 200)),
        );
        await tester.tap(find.text('a.zip'));
        await settle(tester);
        await live(tester, env, 'a', segs(4, each: 200, downloaded: 10));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('4 connections · 0 done'), findsOneWidget);

        // Segment 0 is cut in two: it now ends at 99 and a new one takes 100-199.
        final split = [
          const Segment(id: 0, start: 0, end: 99, downloaded: 10),
          const Segment(id: 4, start: 100, end: 199),
          ...segs(4, each: 200, downloaded: 10).skip(1),
        ];
        await live(tester, env, 'a', split);
        await tester.pump();
        expect(find.text('5 connections · 0 done'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.hasRunningAnimations, isTrue, reason: 'mid-division');
        await tester.pump(const Duration(milliseconds: 250));
        await shutDown(tester, env);
      },
    );

    testWidgets('plain progress does not trigger the dividing animation', (
      tester,
    ) async {
      final env = await boot(tester);
      await add(
        tester,
        env,
        snap('a', DownloadStatus.paused, segments: segs(4, each: 200)),
      );
      await tester.tap(find.text('a.zip'));
      await settle(tester);
      expect(tester.hasRunningAnimations, isFalse);
      await shutDown(tester, env);
    });
  });

  group('connections', () {
    testWidgets('lists each unfinished connection with a live speed', (
      tester,
    ) async {
      final env = await boot(tester);
      await add(tester, env, snap('a', DownloadStatus.downloading));
      await tester.tap(find.text('a.zip'));
      await settle(tester);

      await live(tester, env, 'a', segs(3, each: 4 * mib));
      await tester.runAsync(() => realDelay(150));
      await live(
        tester,
        env,
        'a',
        segs(3, each: 4 * mib, downloaded: mib),
        speed: 3 * mib.toDouble(),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Connections'), findsOneWidget);
      for (final n in [1, 2, 3]) {
        expect(find.text('Connection $n'), findsOneWidget);
      }
      final speeds = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((t) => t.endsWith('/s') && t != '0 B/s')
          .toList();
      expect(speeds.length, greaterThanOrEqualTo(3));
      await shutDown(tester, env);
    });

    testWidgets('finished connections are not listed', (tester) async {
      final env = await boot(tester);
      await add(tester, env, snap('a', DownloadStatus.downloading));
      await tester.tap(find.text('a.zip'));
      await settle(tester);
      final mixed = [...segs(2, downloaded: 100), ...segs(4).skip(2)];
      await live(tester, env, 'a', mixed);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Connection 1'), findsOneWidget);
      expect(find.text('Connection 2'), findsOneWidget);
      expect(find.text('Connection 3'), findsNothing);
      await shutDown(tester, env);
    });

    testWidgets('a paused download has no connection list', (tester) async {
      final env = await boot(tester);
      await add(tester, env, snap('a', DownloadStatus.paused));
      await tester.tap(find.text('a.zip'));
      await settle(tester);
      expect(find.text('Connections'), findsNothing);
      await shutDown(tester, env);
    });
  });

  group('closing', () {
    testWidgets('Escape closes it', (tester) async {
      final env = await boot(tester);
      await add(tester, env, snap('a', DownloadStatus.paused));
      await tester.tap(find.text('a.zip'));
      await settle(tester);
      expect(panelWidth(tester), ShellMetrics.detailWidth);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(cubit<ShellCubit>(tester).state.selection, isEmpty);
      expect(panelWidth(tester), 0);
      expect(find.byType(DetailPanel), findsNothing);
      await shutDown(tester, env);
    });

    testWidgets('the close button closes it', (tester) async {
      final env = await boot(tester);
      await add(tester, env, snap('a', DownloadStatus.paused));
      await tester.tap(find.text('a.zip'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(DetailPanel),
          matching: find.byWidgetPredicate(
            (w) => w is HaulIconButton && w.tooltip == 'Close',
          ),
        ),
      );
      await settle(tester);
      expect(find.byType(DetailPanel), findsNothing);
      await shutDown(tester, env);
    });

    testWidgets('clicking empty space closes it', (tester) async {
      final env = await boot(tester);
      await add(tester, env, snap('a', DownloadStatus.paused));
      await tester.tap(find.text('a.zip'));
      await settle(tester);
      await tester.tapAt(const Offset(500, 700));
      await settle(tester);
      expect(find.byType(DetailPanel), findsNothing);
      await shutDown(tester, env);
    });

    testWidgets('it slides out still showing the download, then goes', (
      tester,
    ) async {
      final env = await boot(tester);
      await add(tester, env, snap('a', DownloadStatus.paused));
      await tester.tap(find.text('a.zip'));
      await settle(tester);
      cubit<ShellCubit>(tester).clearSelection();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DetailPanel), findsOneWidget, reason: 'still leaving');
      expect(panelWidth(tester), inExclusiveRange(0, ShellMetrics.detailWidth));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(DetailPanel), findsNothing);
      await shutDown(tester, env);
    });

    testWidgets('selecting two downloads hides it', (tester) async {
      final env = await boot(tester);
      await add(tester, env, snap('a', DownloadStatus.paused));
      await add(tester, env, snap('b', DownloadStatus.paused));
      await tester.tap(find.text('a.zip'));
      await settle(tester);
      expect(find.byType(DetailPanel), findsOneWidget);
      cubit<ShellCubit>(tester).select({'a', 'b'});
      await settle(tester);
      expect(find.byType(DetailPanel), findsNothing);
      await shutDown(tester, env);
    });
  });

  testWidgets('selecting another download swaps the content', (tester) async {
    final env = await boot(tester);
    await add(tester, env, snap('first', DownloadStatus.paused));
    await add(tester, env, snap('second', DownloadStatus.paused));
    await tester.tap(find.text('first.zip'));
    await settle(tester);
    final panel = find.byType(DetailPanel);
    expect(
      find.descendant(of: panel, matching: find.text('first.zip')),
      findsOneWidget,
    );
    await tester.tap(find.text('second.zip').first);
    await settle(tester);
    expect(
      find.descendant(of: panel, matching: find.text('second.zip')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.text('first.zip')),
      findsNothing,
    );
    await shutDown(tester, env);
  });

  group('buttons', () {
    Finder button(String label) => find.descendant(
      of: find.byType(DetailPanel),
      matching: find.widgetWithText(HaulButton, label),
    );

    testWidgets('show the actions that fit, and work', (tester) async {
      final env = await boot(tester);
      await add(tester, env, snap('a', DownloadStatus.paused));
      await tester.tap(find.text('a.zip'));
      await settle(tester);
      expect(button('Resume'), findsOneWidget);
      expect(button('Show in Finder'), findsOneWidget);
      expect(button('Copy URL'), findsOneWidget);
      expect(button('Pause'), findsNothing);
      expect(button('Open'), findsNothing);

      env.engine.commands.clear();
      await tester.tap(button('Resume'));
      await tester.pump();
      expect(env.engine.commands.whereType<ResumeCommand>().single.id, 'a');
      await shutDown(tester, env);
    });

    testWidgets('a completed download offers Open and Delete file', (
      tester,
    ) async {
      final env = await boot(tester);
      await add(
        tester,
        env,
        snap('a', DownloadStatus.completed, segments: segs(2, downloaded: 100)),
      );
      await tester.tap(find.text('a.zip'));
      await settle(tester);
      expect(button('Open'), findsOneWidget);
      expect(button('Delete file'), findsOneWidget);
      expect(button('Cancel download'), findsNothing);
      await shutDown(tester, env);
    });
  });

  testWidgets('with Reduce Motion it only fades, in 120 ms or less', (
    tester,
  ) async {
    final t = await boot(tester);
    // Rebuild the app with the setting on.
    await shutDown(tester, t);
    final env = await bootReduced(tester);
    await add(tester, env, snap('a', DownloadStatus.paused));
    await tester.tap(find.text('a.zip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    expect(panelWidth(tester), ShellMetrics.detailWidth);
    final shift = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(DetailPanelHost),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(shift.transform.getTranslation().x, 0);
    await shutDown(tester, env);
  });
}
