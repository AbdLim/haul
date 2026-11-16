import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/theme/haul_colors.dart';
import 'package:haul/data/setting_keys.dart';

import '../support/widget_host.dart';

Widget bar({
  double? value = 0.4,
  HaulProgressTone tone = HaulProgressTone.accent,
  bool active = false,
}) => SizedBox(
  width: 200,
  child: HaulProgressBar(value: value, tone: tone, active: active),
);

double fillWidth(WidgetTester tester) {
  final fill = find.descendant(
    of: find.byType(HaulProgressBar),
    matching: find.byType(AnimatedContainer),
  );
  return tester.getSize(fill.first).width;
}

Color fillColor(WidgetTester tester) {
  final box = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byType(HaulProgressBar),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (box.decoration! as BoxDecoration).color!;
}

void main() {
  haulTest('the fill is the right share of the track', (tester) async {
    await pumpHaul(tester, bar(value: 0.4));
    await tester.pumpAndSettle();
    expect(fillWidth(tester), closeTo(80, 0.5));
  });

  haulTest('zero and full fill none and all of the track', (tester) async {
    await pumpHaul(tester, bar(value: 0));
    await tester.pumpAndSettle();
    expect(fillWidth(tester), 0);
    await pumpHaul(tester, bar(value: 1));
    await tester.pumpAndSettle();
    expect(fillWidth(tester), 200);
  });

  haulTest('values outside 0 to 1 are clamped', (tester) async {
    await pumpHaul(tester, bar(value: 1.7));
    await tester.pumpAndSettle();
    expect(fillWidth(tester), 200);
    await pumpHaul(tester, bar(value: -3));
    await tester.pumpAndSettle();
    expect(fillWidth(tester), 0);
  });

  haulTest('it eases to a new value over 250 ms, linearly', (tester) async {
    await pumpHaul(tester, bar(value: 0));
    await tester.pumpAndSettle();
    await pumpHaul(tester, bar(value: 1));
    await tester.pump(const Duration(milliseconds: 125));
    expect(fillWidth(tester), closeTo(100, 5));
    await tester.pump(const Duration(milliseconds: 200));
    expect(fillWidth(tester), 200);
  });

  haulTest('the tones use the theme colours', (tester) async {
    for (final (tone, color) in [
      (HaulProgressTone.accent, HaulColors.dark.accent),
      (HaulProgressTone.success, HaulColors.dark.success),
      (HaulProgressTone.danger, HaulColors.dark.danger),
      (HaulProgressTone.neutral, HaulColors.dark.textSecondary),
    ]) {
      await pumpHaul(tester, bar(tone: tone));
      await tester.pumpAndSettle();
      expect(fillColor(tester), color, reason: tone.name);
    }
  });

  haulTest('turning to success fades the colour over 500 ms', (tester) async {
    await pumpHaul(tester, bar(value: 1));
    await tester.pumpAndSettle();
    await pumpHaul(tester, bar(value: 1, tone: HaulProgressTone.success));
    await tester.pump();
    final box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(HaulProgressBar),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(box.duration, const Duration(milliseconds: 500));
  });

  haulTest('light theme colours are used in the light theme', (tester) async {
    await pumpHaul(
      tester,
      bar(tone: HaulProgressTone.success),
      mode: AppThemeMode.light,
    );
    await tester.pumpAndSettle();
    expect(fillColor(tester), HaulColors.light.success);
  });

  haulTest('an active bar runs a sheen, an idle one does not', (tester) async {
    await pumpHaul(tester, bar(active: true));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.hasRunningAnimations, isTrue);

    await pumpHaul(tester, bar());
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  haulTest('with Reduce Motion the sheen never runs', (tester) async {
    await pumpHaul(tester, bar(active: true), reduceMotion: true);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  haulTest('an unknown total shows a sweep and does not crash', (tester) async {
    await pumpHaul(tester, bar(value: null));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(tester.hasRunningAnimations, isTrue);
  });

  haulTest('a screen reader hears the percentage', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHaul(tester, bar(value: 0.4));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('')), findsWidgets);
    expect(
      tester.getSemantics(find.byType(HaulProgressBar)).value,
      '40 percent',
    );
    handle.dispose();
  });
}
