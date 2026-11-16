import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/motion/view_switch.dart';
import 'package:haul/app/scroll_behavior.dart';

import '../support/widget_host.dart';

class Host extends StatefulWidget {
  const Host({super.key});

  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  bool second = false;
  void flip() => setState(() => second = !second);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    height: 200,
    child: ViewSwitch(
      child: second
          ? const Text('TWO', key: ValueKey('two'))
          : const Text('ONE', key: ValueKey('one')),
    ),
  );
}

void main() {
  haulTest('the old view fades out while the new one fades in and shifts', (
    tester,
  ) async {
    await pumpHaul(tester, const Host());
    final state = tester.state<HostState>(find.byType(Host));
    final restX = tester.getTopLeft(find.text('ONE')).dx;

    state.flip();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    // Mid-way, both are in the tree.
    expect(find.text('ONE'), findsOneWidget);
    expect(find.text('TWO'), findsOneWidget);
    final shiftNow = tester.getTopLeft(find.text('TWO')).dx - restX;
    expect(shiftNow, greaterThan(0));
    expect(shiftNow, lessThanOrEqualTo(ViewSwitch.shift));
    final opacities = tester
        .widgetList<FadeTransition>(find.byType(FadeTransition))
        .map((f) => f.opacity.value)
        .toList();
    expect(opacities.every((o) => o > 0 && o < 1), isTrue);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('ONE'), findsNothing);
    expect(tester.getTopLeft(find.text('TWO')).dx, restX);
  });

  haulTest('it takes 220 ms', (tester) async {
    await pumpHaul(tester, const Host());
    tester.state<HostState>(find.byType(Host)).flip();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('ONE'), findsOneWidget, reason: 'still going at 200 ms');
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump();
    expect(find.text('ONE'), findsNothing, reason: 'done by 240 ms');
  });

  haulTest('with Reduce Motion it only fades, and faster', (tester) async {
    await pumpHaul(tester, const Host(), reduceMotion: true);
    final state = tester.state<HostState>(find.byType(Host));
    final restX = tester.getTopLeft(find.text('ONE')).dx;
    state.flip();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.getTopLeft(find.text('TWO')).dx, restX, reason: 'no shift');
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    expect(find.text('ONE'), findsNothing);
  });

  group('scrolling', () {
    Widget list(Axis axis) => SizedBox(
      width: 300,
      height: 200,
      child: ScrollConfiguration(
        behavior: const HaulScrollBehavior(),
        child: ListView(
          scrollDirection: axis,
          children: [
            for (var i = 0; i < 40; i++)
              SizedBox(width: 100, height: 50, child: Text('row $i')),
          ],
        ),
      ),
    );

    haulTest('a vertical list gets a thin overlay scrollbar', (tester) async {
      await pumpHaul(tester, list(Axis.vertical));
      final bar = tester.widget<RawScrollbar>(find.byType(RawScrollbar));
      expect(bar.thickness, 6);
      expect(bar.thumbVisibility, isNot(true), reason: 'no permanent track');
    });

    haulTest('a sideways strip stays bare', (tester) async {
      await pumpHaul(tester, list(Axis.horizontal));
      expect(find.byType(RawScrollbar), findsNothing);
    });
  });
}
