import 'package:download_engine/download_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/app/cubits/throughput_cubit.dart';
import 'package:haul/features/header/header_band.dart';
import 'package:haul/services/system/window_chrome.dart';
import 'package:haul/features/header/throughput_graph.dart';

import '../support/app_harness.dart';

/// The header's button; the empty list has one of its own.
final headerAddUrl = find.descendant(
  of: find.byType(HeaderBand),
  matching: find.text('Add URL'),
);

const mib = 1024 * 1024;

Future<void> progress(
  WidgetTester tester,
  Env env,
  String id,
  double speed, {
  int total = 100 * mib,
  int done = 0,
}) async {
  env.engine.emit(
    ProgressEvent(
      id: id,
      downloadedBytes: done,
      totalBytes: total,
      bytesPerSecond: speed,
      segmentBytes: const [0],
    ),
  );
  await tester.runAsync(realDelay);
  await tester.pump();
}

void tick(WidgetTester tester) => cubit<ThroughputCubit>(tester).sample();

HaulIconButton iconButton(WidgetTester tester, String tooltip) => tester
    .widgetList<HaulIconButton>(find.byType(HaulIconButton))
    .firstWhere((b) => b.tooltip == tooltip);

void main() {
  testWidgets('idle: says so in words and shows no number', (tester) async {
    final env = await boot(tester);
    expect(find.text('Nothing downloading'), findsOneWidget);
    expect(find.textContaining('/s'), findsNothing);
    expect(find.textContaining('active'), findsNothing);
    await shutDown(tester, env);
  });

  testWidgets('idle: the graph does not animate', (tester) async {
    final env = await boot(tester);
    tick(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    await shutDown(tester, env);
  });

  testWidgets('shows the live speed, the active count and the time left', (
    tester,
  ) async {
    final env = await boot(tester);
    await seed(tester, env, 'a', 'Video', DownloadStatus.downloading);
    await progress(tester, env, 'a', 5.0 * mib);
    tick(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Nothing downloading'), findsNothing);
    expect(find.text('5.00 MB/s'), findsOneWidget);
    expect(find.text('1 active · 20s left'), findsOneWidget);
    await shutDown(tester, env);
  });

  testWidgets('the number glides to a new speed over 300 ms', (tester) async {
    final env = await boot(tester);
    await seed(tester, env, 'a', 'Video', DownloadStatus.downloading);
    await progress(tester, env, 'a', 1.0 * mib);
    tick(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1.00 MB/s'), findsOneWidget);

    await progress(tester, env, 'a', 9.0 * mib);
    tick(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1.00 MB/s'), findsNothing);
    expect(find.text('9.00 MB/s'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('9.00 MB/s'), findsOneWidget);
    await shutDown(tester, env);
  });

  testWidgets('the graph scrolls while something runs', (tester) async {
    final env = await boot(tester);
    await seed(tester, env, 'a', 'Video', DownloadStatus.downloading);
    await progress(tester, env, 'a', 3.0 * mib);
    tick(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ThroughputGraph), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
    await shutDown(tester, env);
  });

  testWidgets('back to idle as soon as the download stops, no stale numbers', (
    tester,
  ) async {
    final env = await boot(tester);
    await seed(tester, env, 'a', 'Video', DownloadStatus.downloading);
    await progress(tester, env, 'a', 5.0 * mib);
    tick(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('5.00 MB/s'), findsOneWidget);

    await seed(tester, env, 'a', 'Video', DownloadStatus.paused);
    tick(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Nothing downloading'), findsOneWidget);
    expect(find.textContaining('/s'), findsNothing);
    await shutDown(tester, env);
  });

  testWidgets('Add URL asks the shell to open the dialog', (tester) async {
    final env = await boot(tester);
    await tester.tap(headerAddUrl);
    await tester.pump();
    expect(cubit<ShellCubit>(tester).state.addDialogOpen, isTrue);
    await shutDown(tester, env);
  });

  testWidgets(
    'Pause all and Resume all start disabled when there is nothing to do',
    (tester) async {
      final env = await boot(tester);
      expect(iconButton(tester, 'Pause all').onPressed, isNull);
      expect(iconButton(tester, 'Resume all').onPressed, isNull);
      await shutDown(tester, env);
    },
  );

  testWidgets('Pause all works while something runs', (tester) async {
    final env = await boot(tester);
    await seed(tester, env, 'a', 'Video', DownloadStatus.downloading);
    expect(iconButton(tester, 'Pause all').onPressed, isNotNull);
    expect(iconButton(tester, 'Resume all').onPressed, isNull);

    env.engine.commands.clear();
    await tester.tap(find.byWidget(iconButton(tester, 'Pause all')));
    expect(env.engine.commands.whereType<PauseCommand>(), hasLength(1));
    await shutDown(tester, env);
  });

  testWidgets('Resume all works while something is paused', (tester) async {
    final env = await boot(tester);
    await seed(tester, env, 'a', 'Video', DownloadStatus.paused);
    expect(iconButton(tester, 'Resume all').onPressed, isNotNull);
    expect(iconButton(tester, 'Pause all').onPressed, isNull);

    env.engine.commands.clear();
    await tester.tap(find.byWidget(iconButton(tester, 'Resume all')));
    expect(env.engine.commands.whereType<ResumeCommand>(), hasLength(1));
    await shutDown(tester, env);
  });

  testWidgets('an expired link is not resumed by Resume all', (tester) async {
    final env = await boot(tester);
    await seed(tester, env, 'a', 'Video', DownloadStatus.needsRefresh);
    expect(iconButton(tester, 'Resume all').onPressed, isNull);
    await shutDown(tester, env);
  });

  testWidgets(
    'typing in the search box filters, and clearing elsewhere empties it',
    (tester) async {
      final env = await boot(tester);
      await tester.enterText(find.byType(EditableText), 'ubuntu');
      await tester.pump();
      expect(cubit<ShellCubit>(tester).state.query, 'ubuntu');

      cubit<ShellCubit>(tester).setQuery('');
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '',
      );
      await shutDown(tester, env);
    },
  );

  testWidgets('the band is 120 tall and the controls sit on its right', (
    tester,
  ) async {
    final env = await boot(tester);
    final band = tester.getRect(find.byType(HeaderBand));
    expect(band.height, 120);
    final add = tester.getCenter(headerAddUrl);
    final title = tester.getCenter(find.text('Nothing downloading'));
    expect(add.dx, greaterThan(title.dx));
    expect(add.dx, greaterThan(band.center.dx));
    await shutDown(tester, env);
  });

  testWidgets(
    'double-clicking the readout zooms the window, like a title bar',
    (tester) async {
      final env = await boot(tester);
      await tester.tap(find.text('Nothing downloading'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Nothing downloading'));
      await tester.pump(const Duration(milliseconds: 400));
      expect((env.deps.chrome as NoWindowChrome).zoomToggles, 1);
      await shutDown(tester, env);
    },
  );

  testWidgets('a click on a button is answered at once, not after a delay', (
    tester,
  ) async {
    final env = await boot(tester);
    // No pump after the tap: a held-back tap would not have happened yet.
    await tester.tap(headerAddUrl);
    expect(cubit<ShellCubit>(tester).state.addDialogOpen, isTrue);
    expect((env.deps.chrome as NoWindowChrome).zoomToggles, 0);
    await shutDown(tester, env);
  });
}
