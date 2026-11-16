import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/theme/haul_colors.dart';
import 'package:haul/data/setting_keys.dart';

import '../support/widget_host.dart';

/// The colour actually painted right now (not the animation's target) for the
/// first animated container under [finder].
Color? fillOf(WidgetTester tester, Finder finder) {
  final animated = find.descendant(
    of: finder,
    matching: find.byType(AnimatedContainer),
  );
  final painted = tester.widget<DecoratedBox>(
    find
        .descendant(of: animated.first, matching: find.byType(DecoratedBox))
        .first,
  );
  return (painted.decoration as BoxDecoration).color;
}

void main() {
  group('HaulButton', () {
    haulTest('shows its label and runs onPressed on tap', (tester) async {
      var taps = 0;
      await pumpHaul(tester, HaulButton(label: 'Go', onPressed: () => taps++));
      expect(find.text('Go'), findsOneWidget);
      await tester.tap(find.text('Go'));
      expect(taps, 1);
    });

    haulTest('a disabled button does nothing and looks dimmed', (tester) async {
      await pumpHaul(tester, const HaulButton(label: 'Off', onPressed: null));
      await tester.tap(find.text('Off'));
      final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, 0.4);
    });

    haulTest('the primary button is filled with the accent', (tester) async {
      await pumpHaul(
        tester,
        HaulButton(label: 'Go', kind: HaulButtonKind.primary, onPressed: () {}),
      );
      expect(fillOf(tester, find.byType(HaulButton)), HaulColors.dark.accent);
    });

    haulTest('a ghost button is see-through until hovered', (tester) async {
      await pumpHaul(
        tester,
        HaulButton(
          label: 'Quiet',
          kind: HaulButtonKind.ghost,
          onPressed: () {},
        ),
      );
      expect(fillOf(tester, find.byType(HaulButton))!.a, 0);

      final g = await mouse(tester);
      await g.moveTo(tester.getCenter(find.text('Quiet')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        fillOf(tester, find.byType(HaulButton)),
        HaulColors.dark.bgSurface,
      );
    });

    haulTest('hover fades the colour over 120 ms rather than jumping', (
      tester,
    ) async {
      await pumpHaul(tester, HaulButton(label: 'Hi', onPressed: () {}));
      final rest = fillOf(tester, find.byType(HaulButton));
      final g = await mouse(tester);
      await g.moveTo(tester.getCenter(find.text('Hi')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final mid = fillOf(tester, find.byType(HaulButton));
      await tester.pump(const Duration(milliseconds: 100));
      final end = fillOf(tester, find.byType(HaulButton));
      expect(mid, isNot(rest));
      expect(mid, isNot(end));
      expect(end, HaulColors.dark.bgElevated);
    });

    haulTest('pressing scales to 0.97 and back, with no ripple', (
      tester,
    ) async {
      await pumpHaul(tester, HaulButton(label: 'Press', onPressed: () {}));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Press')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        0.97,
      );
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1.0,
      );
    });

    haulTest('with Reduce Motion on there is no scale at all', (tester) async {
      await pumpHaul(
        tester,
        HaulButton(label: 'Calm', onPressed: () {}),
        reduceMotion: true,
      );
      expect(find.byType(AnimatedScale), findsNothing);
    });

    haulTest('Tab focuses it, a focus ring shows, Enter and Space activate', (
      tester,
    ) async {
      var taps = 0;
      await pumpHaul(tester, HaulButton(label: 'Key', onPressed: () => taps++));

      BoxBorder? ring() {
        final boxes = tester.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(HaulButton),
            matching: find.byType(DecoratedBox),
          ),
        );
        return boxes
            .where((b) => b.position == DecorationPosition.foreground)
            .map((b) => (b.decoration as BoxDecoration).border)
            .first;
      }

      expect(ring(), isNull, reason: 'no ring before focus');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final border = ring() as Border?;
      expect(border, isNotNull, reason: 'a ring after Tab');
      expect(border!.top.color, HaulColors.dark.accent);
      expect(border.top.width, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(taps, 2);
    });

    haulTest('a mouse click does not leave a focus ring', (tester) async {
      await pumpHaul(tester, HaulButton(label: 'Click', onPressed: () {}));
      await tester.tap(find.text('Click'));
      await tester.pump();
      final rings = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where((b) => b.position == DecorationPosition.foreground)
          .map((b) => (b.decoration as BoxDecoration).border)
          .whereType<Border>();
      expect(rings, isEmpty);
    });

    haulTest('the pointer stays an arrow over a button', (tester) async {
      await pumpHaul(tester, HaulButton(label: 'Arrow', onPressed: () {}));
      final g = await mouse(tester);
      await g.moveTo(tester.getCenter(find.text('Arrow')));
      await tester.pump();
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.basic,
      );
    });

    haulTest('works in the light theme too', (tester) async {
      await pumpHaul(
        tester,
        HaulButton(label: 'L', kind: HaulButtonKind.primary, onPressed: () {}),
        mode: AppThemeMode.light,
      );
      expect(fillOf(tester, find.byType(HaulButton)), HaulColors.light.accent);
    });
  });

  group('HaulIconButton', () {
    haulTest('taps, and shows its tooltip after a pause', (tester) async {
      var taps = 0;
      await pumpHaul(
        tester,
        HaulIconButton(
          icon: HaulIcons.pause,
          tooltip: 'Pause',
          onPressed: () => taps++,
        ),
      );
      await tester.tap(find.byType(HaulIconButton));
      expect(taps, 1);

      final g = await mouse(tester);
      await g.moveTo(tester.getCenter(find.byType(HaulIconButton)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Pause'), findsNothing, reason: 'not yet');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Pause'), findsOneWidget);

      await g.moveTo(const Offset(500, 500));
      await tester.pump();
      expect(find.text('Pause'), findsNothing);
    });

    haulTest('is square', (tester) async {
      await pumpHaul(
        tester,
        HaulIconButton(
          icon: HaulIcons.trash,
          tooltip: 'Delete',
          onPressed: () {},
        ),
      );
      expect(tester.getSize(find.byType(HaulIconButton)), const Size(28, 28));
    });

    haulTest('disabled does nothing', (tester) async {
      await pumpHaul(
        tester,
        const HaulIconButton(
          icon: HaulIcons.trash,
          tooltip: 'Delete',
          onPressed: null,
        ),
      );
      await tester.tap(find.byType(HaulIconButton));
      expect(tester.takeException(), isNull);
    });
  });
}
