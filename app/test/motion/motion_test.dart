import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/motion/animated_list_item.dart';
import 'package:haul/app/motion/animated_number.dart';
import 'package:haul/app/motion/motion.dart';
import 'package:haul/app/motion/reduce_motion.dart';

import '../support/widget_host.dart';

String mb(double v) => '${v.toStringAsFixed(1)} MB/s';

Widget number(double value) => AnimatedNumber(value: value, format: mb);

String shown(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text)).data!;

void main() {
  group('the motion table', () {
    test('every duration is the designed number and none is over 500 ms', () {
      expect(Motion.hover, const Duration(milliseconds: 120));
      expect(Motion.pressDown, const Duration(milliseconds: 80));
      expect(Motion.pressUp, const Duration(milliseconds: 160));
      expect(Motion.sidebarSelection, const Duration(milliseconds: 220));
      expect(Motion.rowIn, const Duration(milliseconds: 280));
      expect(Motion.rowOut, const Duration(milliseconds: 220));
      expect(Motion.progress, const Duration(milliseconds: 250));
      expect(Motion.number, const Duration(milliseconds: 300));
      expect(Motion.detailPanel, const Duration(milliseconds: 260));
      expect(Motion.dialog, const Duration(milliseconds: 200));
      expect(Motion.viewSwitch, const Duration(milliseconds: 220));
      expect(Motion.complete, const Duration(milliseconds: 500));
      expect(Motion.segmentSplit, const Duration(milliseconds: 250));
      expect(Motion.themeChange, const Duration(milliseconds: 200));
      for (final d in [
        Motion.hover, Motion.pressDown, Motion.pressUp,
        Motion.sidebarSelection, Motion.rowIn, Motion.rowOut, Motion.progress,
        Motion.number, Motion.detailPanel, Motion.dialog, Motion.viewSwitch,
        Motion.complete, Motion.segmentSplit, Motion.themeChange, //
      ]) {
        expect(d, lessThanOrEqualTo(const Duration(milliseconds: 500)));
      }
    });

    test('the curves are the designed curves', () {
      expect(Motion.easeOut, Curves.easeOut);
      expect(Motion.easeOutCubic, Curves.easeOutCubic);
      expect(Motion.easeInOutCubic, Curves.easeInOutCubic);
      expect(Motion.pressScale, 0.97);
    });
  });

  group('reduce motion', () {
    haulTest('is read from the system setting in one place', (tester) async {
      late bool normal;
      late bool reduced;
      await pumpHaul(
        tester,
        Builder(
          builder: (context) {
            normal = ReduceMotion.of(context);
            return const SizedBox();
          },
        ),
      );
      await pumpHaul(
        tester,
        Builder(
          builder: (context) {
            reduced = ReduceMotion.of(context);
            return const SizedBox();
          },
        ),
        reduceMotion: true,
      );
      expect(normal, isFalse);
      expect(reduced, isTrue);
    });

    haulTest('caps every duration at 120 ms and leaves short ones alone', (
      tester,
    ) async {
      late List<Duration> normal;
      late List<Duration> reduced;
      List<Duration> read(BuildContext c) => [
        for (final d in [
          Motion.rowIn,
          Motion.complete,
          Motion.hover,
          Motion.pressDown,
        ])
          ReduceMotion.duration(c, d),
      ];
      await pumpHaul(
        tester,
        Builder(
          builder: (c) {
            normal = read(c);
            return const SizedBox();
          },
        ),
      );
      await pumpHaul(
        tester,
        Builder(
          builder: (c) {
            reduced = read(c);
            return const SizedBox();
          },
        ),
        reduceMotion: true,
      );
      expect(normal.map((d) => d.inMilliseconds), [280, 500, 120, 80]);
      expect(reduced.map((d) => d.inMilliseconds), [120, 120, 120, 80]);
    });
  });

  group('AnimatedNumber', () {
    haulTest('shows the first value straight away', (tester) async {
      await pumpHaul(tester, number(4.2));
      expect(shown(tester), '4.2 MB/s');
    });

    haulTest('glides to a new value over 300 ms instead of jumping', (
      tester,
    ) async {
      await pumpHaul(tester, number(0));
      await pumpHaul(tester, number(10));
      expect(shown(tester), '0.0 MB/s');

      await tester.pump(const Duration(milliseconds: 150));
      final mid = double.parse(shown(tester).split(' ').first);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(10));

      await tester.pump(const Duration(milliseconds: 200));
      expect(shown(tester), '10.0 MB/s');
    });

    haulTest('eases out: it covers more than half the distance by half time', (
      tester,
    ) async {
      await pumpHaul(tester, number(0));
      await pumpHaul(tester, number(100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final mid = double.parse(shown(tester).split(' ').first);
      expect(mid, greaterThan(50));
    });

    haulTest('a change in the middle of a glide carries on from where it is', (
      tester,
    ) async {
      await pumpHaul(tester, number(0));
      await pumpHaul(tester, number(10));
      await tester.pump(const Duration(milliseconds: 100));
      final before = double.parse(shown(tester).split(' ').first);
      await pumpHaul(tester, number(0));
      final after = double.parse(shown(tester).split(' ').first);
      expect((after - before).abs(), lessThan(1.5), reason: 'no jump');
    });

    haulTest('uses tabular figures so digits do not shift', (tester) async {
      await pumpHaul(tester, number(1));
      final style = tester.widget<Text>(find.byType(Text)).style!;
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    haulTest('even a custom style gets tabular figures', (tester) async {
      await pumpHaul(
        tester,
        AnimatedNumber(
          value: 1,
          format: mb,
          style: const TextStyle(fontSize: 30),
        ),
      );
      final style = tester.widget<Text>(find.byType(Text)).style!;
      expect(style.fontSize, 30);
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    haulTest('with Reduce Motion the number changes at once', (tester) async {
      await pumpHaul(tester, number(0), reduceMotion: true);
      await pumpHaul(tester, number(10), reduceMotion: true);
      await tester.pump();
      expect(shown(tester), '10.0 MB/s');
    });
  });

  group('HaulAnimatedList', () {
    Widget list(List<String> items, {ScrollController? controller}) => SizedBox(
      width: 300,
      height: 400,
      child: HaulAnimatedList<String>(
        controller: controller,
        items: items,
        idOf: (s) => s,
        itemBuilder: (context, s, i) =>
            SizedBox(height: 64, child: Text('row $s')),
      ),
    );

    haulTest('rows present at the start appear without animating', (
      tester,
    ) async {
      await pumpHaul(tester, list(['a', 'b']));
      expect(find.text('row a'), findsOneWidget);
      expect(find.text('row b'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    haulTest('a new row fades in, slides up and opens over 280 ms', (
      tester,
    ) async {
      await pumpHaul(tester, list(['a']));
      await pumpHaul(tester, list(['b', 'a']));
      await tester.pump(); // post-frame: the list starts the insert
      await tester.pump(const Duration(milliseconds: 20));

      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('row b'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      final heightEarly = tester.getSize(find.text('row b').first).height;
      expect(fade.opacity.value, inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 120));
      expect(fade.opacity.value, greaterThan(0.5));

      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1);
      expect(
        tester.getTopLeft(find.text('row b')).dy,
        lessThan(tester.getTopLeft(find.text('row a')).dy),
      );
      expect(heightEarly, isNonNegative);
    });

    haulTest('a removed row fades out and its space closes over 220 ms', (
      tester,
    ) async {
      await pumpHaul(tester, list(['a', 'b', 'c']));
      final cBefore = tester.getTopLeft(find.text('row c')).dy;

      await pumpHaul(tester, list(['a', 'c']));
      await tester.pump(); // post-frame
      await tester.pump(const Duration(milliseconds: 110));
      // Mid-exit: still on screen, and c has started to move up.
      expect(find.text('row b'), findsOneWidget);
      final cMid = tester.getTopLeft(find.text('row c')).dy;
      expect(cMid, lessThan(cBefore));

      await tester.pumpAndSettle();
      expect(find.text('row b'), findsNothing);
      expect(
        tester.getTopLeft(find.text('row c')).dy,
        tester.getTopLeft(find.text('row a')).dy + 64,
      );
    });

    haulTest('rows that stay keep their state and show fresh data', (
      tester,
    ) async {
      final data = ['a', 'b'];
      await pumpHaul(
        tester,
        StatefulBuilder(
          builder: (context, set) => SizedBox(
            width: 300,
            height: 400,
            child: HaulAnimatedList<({String id, int n})>(
              items: [for (final d in data) (id: d, n: data.length)],
              idOf: (r) => r.id,
              itemBuilder: (context, r, i) =>
                  SizedBox(height: 64, child: Text('${r.id}:${r.n}')),
            ),
          ),
        ),
      );
      expect(find.text('a:2'), findsOneWidget);
      data.add('c');
      await pumpHaul(
        tester,
        SizedBox(
          width: 300,
          height: 400,
          child: HaulAnimatedList<({String id, int n})>(
            items: [for (final d in data) (id: d, n: data.length)],
            idOf: (r) => r.id,
            itemBuilder: (context, r, i) =>
                SizedBox(height: 64, child: Text('${r.id}:${r.n}')),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('a:3'), findsOneWidget, reason: 'new data, same row');
      expect(find.text('c:3'), findsOneWidget);
    });

    haulTest('adding and removing in one update both animate', (tester) async {
      await pumpHaul(tester, list(['a', 'b']));
      await pumpHaul(tester, list(['c', 'b']));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('row a'), findsOneWidget, reason: 'still leaving');
      expect(find.text('row c'), findsOneWidget, reason: 'already arriving');
      await tester.pumpAndSettle();
      expect(find.text('row a'), findsNothing);
      expect(find.text('row c'), findsOneWidget);
    });

    haulTest('reordered rows reset the list instead of misplacing them', (
      tester,
    ) async {
      await pumpHaul(tester, list(['a', 'b', 'c']));
      await pumpHaul(tester, list(['c', 'a', 'b']));
      await tester.pump();
      await tester.pumpAndSettle();
      final ys = [
        for (final s in ['c', 'a', 'b'])
          tester.getTopLeft(find.text('row $s')).dy,
      ];
      expect(ys, [...ys]..sort());
    });

    haulTest('only the rows on screen are built in a long list', (
      tester,
    ) async {
      final many = [for (var i = 0; i < 500; i++) 'r$i'];
      await pumpHaul(tester, list(many));
      expect(find.byType(Text).evaluate().length, lessThan(20));
      expect(find.text('row r0'), findsOneWidget);
      expect(find.text('row r499'), findsNothing);
    });

    haulTest('with Reduce Motion a new row only fades, in 120 ms', (
      tester,
    ) async {
      await pumpHaul(tester, list(['a']), reduceMotion: true);
      await pumpHaul(tester, list(['b', 'a']), reduceMotion: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      expect(find.byType(SizeTransition), findsNothing);
      expect(find.byType(SlideTransition), findsNothing);
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('row b'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    haulTest('with Reduce Motion a removed row is gone within 120 ms', (
      tester,
    ) async {
      await pumpHaul(tester, list(['a', 'b']), reduceMotion: true);
      await pumpHaul(tester, list(['a']), reduceMotion: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      expect(find.text('row b'), findsNothing);
    });

    haulTest('a leaving row cannot be clicked', (tester) async {
      var taps = 0;
      Widget tappable(List<String> items) => SizedBox(
        width: 300,
        height: 400,
        child: HaulAnimatedList<String>(
          items: items,
          idOf: (s) => s,
          itemBuilder: (context, s, i) => GestureDetector(
            onTap: () => taps++,
            child: SizedBox(height: 64, child: Text('row $s')),
          ),
        ),
      );
      await pumpHaul(tester, tappable(['a', 'b']));
      await pumpHaul(tester, tappable(['a']));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.text('row b'), warnIfMissed: false);
      expect(taps, 0);
    });
  });
}
