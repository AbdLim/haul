import 'package:download_engine/download_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/cubits/browser_status_cubit.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/app/haul_app.dart';
import 'package:haul/app/theme/haul_theme.dart';
import 'package:haul/data/categories_repository.dart';
import 'package:haul/features/sidebar/sidebar.dart';
import 'package:haul/features/sidebar/sidebar_item.dart';

import '../support/app_harness.dart';
import '../support/test_deps.dart';

double highlightTarget(WidgetTester tester) => tester
    .widget<AnimatedPositioned>(find.byKey(const ValueKey('sidebar-highlight')))
    .top!;

double highlightPainted(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const ValueKey('sidebar-highlight'))).dy;

String countFor(WidgetTester tester, String label) {
  final row = find.ancestor(
    of: find.text(label),
    matching: find.byType(SidebarItem),
  );
  final texts = tester
      .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
      .map((t) => t.data)
      .toList();
  return texts.last!;
}

void main() {
  group('highlight position', () {
    test('is a whole number of rows down the status list', () {
      for (var i = 0; i < StatusFilter.values.length; i++) {
        expect(
          Sidebar.highlightTop(
            status: StatusFilter.values[i],
            categoryIndex: null,
          ),
          i * SidebarItem.height,
        );
      }
    });

    test('categories sit below the status list and the heading', () {
      final base = 5 * SidebarItem.height + Sidebar.sectionHeader;
      expect(
        Sidebar.highlightTop(status: StatusFilter.all, categoryIndex: 0),
        base,
      );
      expect(
        Sidebar.highlightTop(status: StatusFilter.all, categoryIndex: 3),
        base + 3 * SidebarItem.height,
      );
    });
  });

  testWidgets('shows the filters, categories, indicator and Settings', (
    tester,
  ) async {
    final env = await boot(tester);
    for (final t in ['All', 'Active', 'Paused', 'Completed', 'Failed']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('CATEGORIES'), findsOneWidget);
    for (final t in builtInCategories.map((c) => c.$1)) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Browser not paired'), findsOneWidget);
    expect(find.text('Haul'), findsOneWidget);
    await shutDown(tester, env);
  });

  testWidgets('every count starts at zero', (tester) async {
    final env = await boot(tester);
    for (final label in [
      'All',
      'Active',
      'Paused',
      'Completed',
      'Failed',
      'Video',
    ]) {
      expect(countFor(tester, label), '0', reason: label);
    }
    await shutDown(tester, env);
  });

  testWidgets('counts follow the downloads and update as they change', (
    tester,
  ) async {
    final env = await boot(tester);
    await seed(tester, env, 'a', 'Video', DownloadStatus.downloading);
    await seed(tester, env, 'b', 'Video', DownloadStatus.paused);
    await seed(tester, env, 'c', 'Compressed', DownloadStatus.completed);
    await seed(tester, env, 'd', 'Documents', DownloadStatus.failed);
    await seed(tester, env, 'e', 'Documents', DownloadStatus.needsRefresh);

    expect(countFor(tester, 'All'), '5');
    expect(countFor(tester, 'Active'), '1');
    expect(countFor(tester, 'Paused'), '1');
    expect(countFor(tester, 'Completed'), '1');
    expect(countFor(tester, 'Failed'), '2', reason: 'failed plus expired link');
    expect(countFor(tester, 'Video'), '2');
    expect(countFor(tester, 'Compressed'), '1');
    expect(countFor(tester, 'Documents'), '2');
    expect(countFor(tester, 'Music'), '0');

    // A paused download is resumed: it moves from Paused to Active.
    env.engine.emit(
      SnapshotEvent(
        DownloadSnapshot(
          request: DownloadRequest(
            id: 'b',
            url: Uri.parse('https://e.com/b'),
            saveDir: '/d',
          ),
          status: DownloadStatus.downloading,
          fileName: 'b.bin',
        ),
      ),
    );
    await tester.runAsync(realDelay);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(countFor(tester, 'Active'), '2');
    expect(countFor(tester, 'Paused'), '0');
    await shutDown(tester, env);
  });

  testWidgets('clicking a status filter selects it', (tester) async {
    final env = await boot(tester);
    await tester.tap(find.text('Paused'));
    await tester.pump();
    final shell = cubit<ShellCubit>(tester);
    expect(shell.state.status, StatusFilter.paused);
    expect(shell.state.categoryId, isNull);
    await shutDown(tester, env);
  });

  testWidgets('clicking a category selects it and clears the status filter', (
    tester,
  ) async {
    final env = await boot(tester);
    await tester.tap(find.text('Paused'));
    await tester.pump();
    await tester.tap(find.text('Video'));
    await tester.pump();
    final shell = cubit<ShellCubit>(tester);
    expect(shell.state.categoryId, env.categoryIds['Video']);
    expect(shell.state.status, StatusFilter.all);
    await shutDown(tester, env);
  });

  testWidgets('the highlight slides between rows over 220 ms, easing out', (
    tester,
  ) async {
    final env = await boot(tester);
    expect(highlightTarget(tester), 0);
    final start = highlightPainted(tester);

    await tester.tap(find.text('Completed')); // row 3
    await tester.pump();
    expect(highlightTarget(tester), 3 * SidebarItem.height);
    expect(
      tester
          .widget<AnimatedPositioned>(
            find.byKey(const ValueKey('sidebar-highlight')),
          )
          .duration,
      const Duration(milliseconds: 220),
    );

    await tester.pump(const Duration(milliseconds: 110));
    final mid = highlightPainted(tester) - start;
    expect(mid, greaterThan(0));
    expect(mid, lessThan(3 * SidebarItem.height));
    // Ease out: more than half the way by half time.
    expect(mid, greaterThan(1.5 * SidebarItem.height));

    await tester.pump(const Duration(milliseconds: 200));
    expect(highlightPainted(tester) - start, 3 * SidebarItem.height);
    await shutDown(tester, env);
  });

  testWidgets('the highlight also moves down to a category row', (
    tester,
  ) async {
    final env = await boot(tester);
    await tester.tap(find.text('Video')); // fourth category
    await tester.pumpAndSettle();
    expect(
      highlightTarget(tester),
      5 * SidebarItem.height + Sidebar.sectionHeader + 3 * SidebarItem.height,
    );
    await shutDown(tester, env);
  });

  testWidgets('the selected row is drawn in the accent colour', (tester) async {
    final env = await boot(tester);
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    // The colour is on the animated text style wrapped around the label.
    Color colorOf(String label) =>
        DefaultTextStyle.of(tester.element(find.text(label))).style.color!;
    // Whichever theme the system picked, the selected row uses its accent text.
    final accent = HaulTheme.of(tester.element(find.byType(Sidebar)))
        .colors
        .accentText;
    expect(colorOf('Active'), accent);
    expect(colorOf('All'), isNot(accent));
    await shutDown(tester, env);
  });

  testWidgets(
    'Settings opens the settings view, and the highlight steps back',
    (tester) async {
      final env = await boot(tester);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(cubit<ShellCubit>(tester).state.section, MainSection.settings);
      final opacity = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byKey(const ValueKey('sidebar-highlight')),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacity.opacity, 0);

      await tester.tap(find.text('Settings')); // again: back to the list
      await tester.pumpAndSettle();
      expect(cubit<ShellCubit>(tester).state.section, MainSection.downloads);
      await shutDown(tester, env);
    },
  );

  testWidgets('choosing a filter while in Settings goes back to the list', (
    tester,
  ) async {
    final env = await boot(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Failed'));
    await tester.pumpAndSettle();
    final shell = cubit<ShellCubit>(tester);
    expect(shell.state.section, MainSection.downloads);
    expect(shell.state.status, StatusFilter.failed);
    await shutDown(tester, env);
  });

  testWidgets('the browser indicator follows the connection', (tester) async {
    final env = await boot(tester);
    expect(find.text('Browser not paired'), findsOneWidget);
    cubit<BrowserStatusCubit>(tester).connected();
    await tester.pumpAndSettle();
    expect(find.text('Browser connected'), findsOneWidget);
    expect(find.text('Browser not paired'), findsNothing);
    cubit<BrowserStatusCubit>(tester).notPaired();
    await tester.pumpAndSettle();
    expect(find.text('Browser not paired'), findsOneWidget);
    await shutDown(tester, env);
  });

  testWidgets('Tab and Enter pick a filter from the keyboard', (tester) async {
    final env = await boot(tester);
    // Tab through the window until the Active row has focus.
    var found = false;
    for (var i = 0; i < 30 && !found; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      final ctx = FocusManager.instance.primaryFocus?.context;
      final row = ctx?.findAncestorWidgetOfExactType<SidebarItem>();
      found = row?.label == 'Active';
    }
    expect(found, isTrue, reason: 'Tab never reached the Active row');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(cubit<ShellCubit>(tester).state.status, StatusFilter.active);
    await shutDown(tester, env);
  });

  testWidgets('with Reduce Motion the highlight moves in 120 ms or less', (
    tester,
  ) async {
    final t = (await tester.runAsync(makeTestDeps))!;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(1200, 800),
            disableAnimations: true,
          ),
          child: HaulApp(deps: t.deps, native: false),
        ),
      );
      await realDelay();
    });
    await tester.pump(const Duration(milliseconds: 300));
    final env = Env(t.deps, t.engine, const {});
    final positioned = tester.widget<AnimatedPositioned>(
      find.byKey(const ValueKey('sidebar-highlight')),
    );
    expect(
      positioned.duration,
      lessThanOrEqualTo(const Duration(milliseconds: 120)),
    );
    await shutDown(tester, env);
  });
}
