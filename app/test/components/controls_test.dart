import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/theme/haul_colors.dart';

import '../support/widget_host.dart';

void main() {
  group('HaulTextField', () {
    haulTest('typing updates the controller and reports changes', (
      tester,
    ) async {
      final c = TextEditingController();
      final changes = <String>[];
      await pumpHaul(
        tester,
        SizedBox(
          width: 300,
          child: HaulTextField(controller: c, onChanged: changes.add),
        ),
      );
      await tester.tap(find.byType(HaulTextField));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'hello');
      expect(c.text, 'hello');
      expect(changes, ['hello']);
    });

    haulTest('the hint shows only while the field is empty', (tester) async {
      final c = TextEditingController();
      await pumpHaul(
        tester,
        SizedBox(
          width: 300,
          child: HaulTextField(controller: c, hint: 'Paste a link'),
        ),
      );
      expect(find.text('Paste a link'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'x');
      await tester.pump();
      expect(find.text('Paste a link'), findsNothing);
    });

    haulTest('clicking focuses it and the outline turns accent', (
      tester,
    ) async {
      await pumpHaul(
        tester,
        const SizedBox(width: 300, child: HaulTextField(hint: 'a')),
      );
      Color outline() {
        final box = tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byType(HaulTextField),
            matching: find.byType(AnimatedContainer),
          ),
        );
        return ((box.decoration as BoxDecoration).border! as Border).top.color;
      }

      expect(outline(), HaulColors.dark.borderSubtle);
      await tester.tap(find.byType(HaulTextField));
      await tester.pump();
      expect(outline(), HaulColors.dark.accent);
    });

    haulTest('an invalid field has a danger outline', (tester) async {
      await pumpHaul(
        tester,
        const SizedBox(width: 300, child: HaulTextField(invalid: true)),
      );
      final box = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(HaulTextField),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        ((box.decoration as BoxDecoration).border! as Border).top.color,
        HaulColors.dark.danger,
      );
    });

    haulTest('submitting with Enter calls onSubmitted', (tester) async {
      String? submitted;
      await pumpHaul(
        tester,
        SizedBox(
          width: 300,
          child: HaulTextField(onSubmitted: (v) => submitted = v),
        ),
      );
      await tester.enterText(find.byType(EditableText), 'go');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, 'go');
    });

    haulTest('a disabled field ignores taps', (tester) async {
      final f = FocusNode();
      addTearDown(f.dispose);
      await pumpHaul(
        tester,
        SizedBox(
          width: 300,
          child: HaulTextField(focusNode: f, enabled: false),
        ),
      );
      await tester.tap(find.byType(HaulTextField));
      await tester.pump();
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.readOnly, isTrue);
    });

    haulTest('can show a leading icon and hide a password', (tester) async {
      await pumpHaul(
        tester,
        const SizedBox(
          width: 300,
          child: HaulTextField(
            obscureText: true,
            leading: HaulIcon(HaulIcons.link),
          ),
        ),
      );
      expect(find.byType(HaulIcon), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isTrue,
      );
    });
  });

  group('HaulToggle', () {
    haulTest('tapping flips it', (tester) async {
      var value = false;
      await pumpHaul(
        tester,
        StatefulBuilder(
          builder: (context, set) =>
              HaulToggle(value: value, onChanged: (v) => set(() => value = v)),
        ),
      );
      await tester.tap(find.byType(HaulToggle));
      await tester.pump();
      expect(value, isTrue);
      await tester.tap(find.byType(HaulToggle));
      await tester.pump();
      expect(value, isFalse);
    });

    haulTest('the knob slides over 120 ms', (tester) async {
      var value = false;
      await pumpHaul(
        tester,
        StatefulBuilder(
          builder: (context, set) =>
              HaulToggle(value: value, onChanged: (v) => set(() => value = v)),
        ),
      );
      Alignment knob() =>
          tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment
              as Alignment;
      expect(knob(), Alignment.centerLeft);
      await tester.tap(find.byType(HaulToggle));
      await tester.pump();
      expect(knob(), Alignment.centerRight);
      expect(
        tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).duration,
        const Duration(milliseconds: 120),
      );
    });

    haulTest('Tab then Space toggles it from the keyboard', (tester) async {
      var value = false;
      await pumpHaul(
        tester,
        StatefulBuilder(
          builder: (context, set) =>
              HaulToggle(value: value, onChanged: (v) => set(() => value = v)),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(value, isTrue);
    });

    haulTest('disabled does nothing', (tester) async {
      await pumpHaul(tester, const HaulToggle(value: true, onChanged: null));
      await tester.tap(find.byType(HaulToggle));
      expect(tester.takeException(), isNull);
    });
  });

  group('HaulCheckbox', () {
    haulTest('tapping the box or the label flips it', (tester) async {
      var value = false;
      await pumpHaul(
        tester,
        StatefulBuilder(
          builder: (context, set) => HaulCheckbox(
            value: value,
            label: 'Keep awake',
            onChanged: (v) => set(() => value = v),
          ),
        ),
      );
      await tester.tap(find.text('Keep awake'));
      await tester.pump();
      expect(value, isTrue);
      await tester.tap(find.byType(HaulCheckbox));
      await tester.pump();
      expect(value, isFalse);
    });

    haulTest('the tick is shown only when checked', (tester) async {
      Future<double> tickOpacity(bool v) async {
        await pumpHaul(tester, HaulCheckbox(value: v, onChanged: (_) {}));
        await tester.pump(const Duration(milliseconds: 200));
        return tester
            .widget<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .opacity;
      }

      expect(await tickOpacity(true), 1);
      expect(await tickOpacity(false), 0);
    });

    haulTest('Space toggles it from the keyboard', (tester) async {
      var value = false;
      await pumpHaul(
        tester,
        StatefulBuilder(
          builder: (context, set) => HaulCheckbox(
            value: value,
            onChanged: (v) => set(() => value = v),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(value, isTrue);
    });
  });

  group('HaulSlider', () {
    Widget slider(
      double Function() get,
      void Function(double) set, {
      int? divisions,
      double min = 0,
      double max = 1,
    }) {
      return StatefulBuilder(
        builder: (context, setState) => SizedBox(
          width: 216,
          child: HaulSlider(
            value: get(),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (v) => setState(() => set(v)),
          ),
        ),
      );
    }

    haulTest('clicking the track moves the value there', (tester) async {
      var v = 0.0;
      await pumpHaul(tester, slider(() => v, (x) => v = x));
      final box = tester.getRect(find.byType(HaulSlider));
      await tester.tapAt(Offset(box.left + 8 + 100, box.center.dy)); // halfway
      await tester.pump();
      expect(v, closeTo(0.5, 0.02));
    });

    haulTest('dragging follows the pointer and stays in range', (tester) async {
      var v = 0.0;
      await pumpHaul(tester, slider(() => v, (x) => v = x));
      final box = tester.getRect(find.byType(HaulSlider));
      await tester.dragFrom(
        Offset(box.left + 8, box.center.dy),
        const Offset(1000, 0),
      );
      await tester.pump();
      expect(v, 1.0);
    });

    haulTest('divisions snap to steps', (tester) async {
      var v = 0.0;
      await pumpHaul(
        tester,
        slider(() => v, (x) => v = x, divisions: 4, min: 0, max: 16),
      );
      final box = tester.getRect(find.byType(HaulSlider));
      await tester.tapAt(Offset(box.left + 8 + 100 * 0.6 * 2, box.center.dy));
      await tester.pump();
      expect(v, anyOf(0, 4, 8, 12, 16));
      expect(v % 4, 0);
    });

    haulTest('arrow keys step the value', (tester) async {
      var v = 0.5;
      await pumpHaul(tester, slider(() => v, (x) => v = x));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(v, greaterThan(0.5));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(v, lessThan(0.5));
    });

    haulTest('a disabled slider cannot be moved', (tester) async {
      await pumpHaul(
        tester,
        const SizedBox(
          width: 200,
          child: HaulSlider(value: 0.2, onChanged: null),
        ),
      );
      await tester.tap(find.byType(HaulSlider));
      expect(tester.takeException(), isNull);
    });
  });

  group('HaulSegmentedControl', () {
    Widget control(String Function() get, void Function(String) set) =>
        StatefulBuilder(
          builder: (context, setState) => HaulSegmentedControl<String>(
            segments: const [
              HaulSegment('a', 'System'),
              HaulSegment('b', 'Dark'),
              HaulSegment('c', 'Light'),
            ],
            value: get(),
            onChanged: (v) => setState(() => set(v)),
          ),
        );

    haulTest('tapping a segment chooses it', (tester) async {
      var v = 'a';
      await pumpHaul(tester, control(() => v, (x) => v = x));
      await tester.tap(find.text('Light'));
      await tester.pump();
      expect(v, 'c');
    });

    haulTest('the highlight slides to the new choice over 220 ms', (
      tester,
    ) async {
      var v = 'a';
      await pumpHaul(tester, control(() => v, (x) => v = x));
      Alignment at() =>
          tester
                  .widget<AnimatedAlign>(
                    find.byKey(const ValueKey('segment-highlight')),
                  )
                  .alignment
              as Alignment;
      expect(at().x, -1);
      await tester.tap(find.text('Dark'));
      await tester.pump();
      expect(at().x, 0);
      await tester.tap(find.text('Light'));
      await tester.pump();
      expect(at().x, 1);
      expect(
        tester
            .widget<AnimatedAlign>(
              find.byKey(const ValueKey('segment-highlight')),
            )
            .duration,
        const Duration(milliseconds: 220),
      );
    });

    haulTest('arrow keys move the choice', (tester) async {
      var v = 'b';
      await pumpHaul(tester, control(() => v, (x) => v = x));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(v, 'c');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(v, 'c', reason: 'stops at the end');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(v, 'a');
    });
  });

  group('HaulChip', () {
    haulTest('shows its label and a working close button', (tester) async {
      var deleted = 0;
      await pumpHaul(
        tester,
        HaulChip(label: 'dmg', onDeleted: () => deleted++),
      );
      expect(find.text('dmg'), findsOneWidget);
      await tester.tap(find.byType(HaulIcon));
      expect(deleted, 1);
    });

    haulTest('without onDeleted there is no close button', (tester) async {
      await pumpHaul(tester, const HaulChip(label: 'zip'));
      expect(find.byType(HaulIcon), findsNothing);
    });
  });
}
