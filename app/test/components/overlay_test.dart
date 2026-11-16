import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/theme/haul_colors.dart';

import '../support/widget_host.dart';

Future<void> rightClick(WidgetTester tester, Offset at) async {
  final g = await tester.startGesture(
    at,
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await g.up();
  await tester.pumpAndSettle();
}

void main() {
  group('context menu', () {
    Widget region({
      required List<String> log,
      List<HaulMenuEntry>? entries,
      VoidCallback? onOpen,
    }) => HaulContextMenuRegion(
      onOpen: onOpen,
      entriesBuilder: (_) =>
          entries ??
          [
            HaulMenuItem(label: 'Open', onSelected: () => log.add('open')),
            HaulMenuItem(label: 'Copy URL', onSelected: () => log.add('copy')),
            const HaulMenuDivider(),
            HaulMenuItem(
              label: 'Delete file',
              destructive: true,
              onSelected: () => log.add('delete'),
            ),
            const HaulMenuItem(label: 'Unavailable', onSelected: null),
          ],
      child: const SizedBox(width: 300, height: 100, child: Text('row')),
    );

    haulTest('right-click opens it with the current items', (tester) async {
      final log = <String>[];
      await pumpHaul(tester, region(log: log));
      expect(find.text('Open'), findsNothing);
      await rightClick(tester, const Offset(50, 40));
      for (final t in ['Open', 'Copy URL', 'Delete file', 'Unavailable']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
    });

    haulTest('a normal left click does not open it', (tester) async {
      await pumpHaul(tester, region(log: []));
      await tester.tapAt(const Offset(50, 40));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsNothing);
    });

    haulTest('choosing an item runs it and closes the menu', (tester) async {
      final log = <String>[];
      await pumpHaul(tester, region(log: log));
      await rightClick(tester, const Offset(50, 40));
      await tester.tap(find.text('Copy URL'));
      await tester.pumpAndSettle();
      expect(log, ['copy']);
      expect(find.text('Copy URL'), findsNothing);
    });

    haulTest('an unavailable item does nothing', (tester) async {
      final log = <String>[];
      await pumpHaul(tester, region(log: log));
      await rightClick(tester, const Offset(50, 40));
      await tester.tap(find.text('Unavailable'));
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(
        find.text('Unavailable'),
        findsOneWidget,
        reason: 'menu stays open',
      );
    });

    haulTest('a destructive item is drawn in the danger colour', (
      tester,
    ) async {
      await pumpHaul(tester, region(log: []));
      await rightClick(tester, const Offset(50, 40));
      final text = tester.widget<Text>(find.text('Delete file'));
      expect(text.style!.color, HaulColors.dark.danger);
    });

    haulTest('Escape and an outside click both close it', (tester) async {
      await pumpHaul(tester, region(log: []));
      await rightClick(tester, const Offset(50, 40));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsNothing);

      await rightClick(tester, const Offset(50, 40));
      expect(find.text('Open'), findsOneWidget);
      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsNothing);
    });

    haulTest('arrow keys and Enter choose an item', (tester) async {
      final log = <String>[];
      await pumpHaul(tester, region(log: log));
      await rightClick(tester, const Offset(50, 40));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(log, ['copy']);
    });

    haulTest('arrow keys skip dividers and unavailable items', (tester) async {
      final log = <String>[];
      await pumpHaul(tester, region(log: log));
      await rightClick(tester, const Offset(50, 40));
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(log, ['delete']);
    });

    haulTest('onOpen runs first, so a row can select itself', (tester) async {
      final log = <String>[];
      await pumpHaul(
        tester,
        region(log: log, onOpen: () => log.add('selected')),
      );
      await rightClick(tester, const Offset(50, 40));
      expect(log, ['selected']);
    });

    haulTest('a menu with no entries does not open', (tester) async {
      await pumpHaul(tester, region(log: [], entries: const []));
      await rightClick(tester, const Offset(50, 40));
      expect(find.byType(HaulMenuItem), findsNothing);
    });

    haulTest('near the right and bottom edge the menu stays on screen', (
      tester,
    ) async {
      await pumpHaul(
        tester,
        HaulContextMenuRegion(
          entriesBuilder: (_) => [
            for (var i = 0; i < 6; i++)
              HaulMenuItem(label: 'Item number $i', onSelected: () {}),
          ],
          child: const SizedBox(width: 800 - 32, height: 600 - 32),
        ),
      );
      await rightClick(tester, const Offset(770, 570));
      final rect = tester.getRect(find.text('Item number 5'));
      expect(rect.right, lessThanOrEqualTo(800));
      expect(rect.bottom, lessThanOrEqualTo(600));
    });

    haulTest('it opens with a short fade and scale, then settles', (
      tester,
    ) async {
      await pumpHaul(tester, region(log: []));
      final g = await tester.startGesture(
        const Offset(50, 40),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('Open'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, lessThan(1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(fade.opacity.value, 1);
    });
  });

  group('HaulDropdown', () {
    Widget dropdown(String? Function() get, void Function(String) set) =>
        StatefulBuilder(
          builder: (context, setState) => HaulDropdown<String>(
            value: get(),
            width: 200,
            items: const [
              HaulDropdownItem('zip', 'Compressed'),
              HaulDropdownItem('mp4', 'Video'),
              HaulDropdownItem('pdf', 'Documents'),
            ],
            onChanged: (v) => setState(() => set(v)),
          ),
        );

    haulTest('shows the chosen label, or the hint', (tester) async {
      await pumpHaul(tester, dropdown(() => 'mp4', (_) {}));
      expect(find.text('Video'), findsOneWidget);

      await pumpHaul(tester, dropdown(() => null, (_) {}));
      expect(find.text('Choose'), findsOneWidget);
    });

    haulTest('opens a menu under it and picking an item changes the value', (
      tester,
    ) async {
      String? v = 'zip';
      await pumpHaul(tester, dropdown(() => v, (x) => v = x));
      await tester.tap(find.byType(HaulDropdown<String>));
      await tester.pumpAndSettle();
      expect(find.text('Documents'), findsOneWidget);

      final buttonBottom = tester
          .getBottomLeft(find.byType(HaulDropdown<String>))
          .dy;
      expect(
        tester.getTopLeft(find.text('Documents')).dy,
        greaterThan(buttonBottom),
      );

      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();
      expect(v, 'pdf');
      expect(find.text('Video'), findsNothing, reason: 'menu closed');
    });

    haulTest('the current choice has a tick', (tester) async {
      await pumpHaul(tester, dropdown(() => 'mp4', (_) {}));
      await tester.tap(find.byType(HaulDropdown<String>));
      await tester.pumpAndSettle();
      expect(find.byType(HaulIcon), findsNWidgets(2)); // caret plus one tick
    });

    haulTest('Tab, Enter, Down, Enter chooses from the keyboard', (
      tester,
    ) async {
      String? v = 'zip';
      await pumpHaul(tester, dropdown(() => v, (x) => v = x));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(v, 'zip', reason: 'first Down lands on the first item');
    });

    haulTest('disabled does not open', (tester) async {
      await pumpHaul(
        tester,
        const HaulDropdown<String>(
          value: 'a',
          items: [HaulDropdownItem('a', 'Aye')],
          onChanged: null,
        ),
      );
      await tester.tap(find.byType(HaulDropdown<String>));
      await tester.pumpAndSettle();
      expect(find.byType(HaulMenuItem), findsNothing);
    });
  });

  group('HaulDialog', () {
    Widget opener({bool dismissible = true, List<String>? log}) => Builder(
      builder: (context) => HaulButton(
        label: 'Open',
        onPressed: () => showHaulDialog<void>(
          context,
          barrierDismissible: dismissible,
          builder: (ctx) => HaulDialog(
            title: 'Remove download?',
            actions: [
              HaulButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              HaulButton(
                label: 'Remove',
                kind: HaulButtonKind.primary,
                onPressed: () {
                  log?.add('remove');
                  Navigator.of(ctx).pop();
                },
              ),
            ],
            child: const Text('The file stays on disk.'),
          ),
        ),
      ),
    );

    haulTest('opens with its title, content and buttons', (tester) async {
      await pumpHaul(tester, opener());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Remove download?'), findsOneWidget);
      expect(find.text('The file stays on disk.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });

    haulTest('scales in from 0.96 while fading, over 200 ms', (tester) async {
      await pumpHaul(tester, opener());
      await tester.tap(find.text('Open'));
      await tester.pump();
      ScaleTransition scale() => tester.widget<ScaleTransition>(
        find
            .ancestor(
              of: find.text('Remove download?'),
              matching: find.byType(ScaleTransition),
            )
            .first,
      );
      expect(scale().scale.value, closeTo(0.96, 0.005));
      await tester.pump(const Duration(milliseconds: 100));
      expect(scale().scale.value, inExclusiveRange(0.96, 1.0));
      await tester.pump(const Duration(milliseconds: 150));
      expect(scale().scale.value, 1.0);
    });

    haulTest('Escape closes it', (tester) async {
      await pumpHaul(tester, opener());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Remove download?'), findsNothing);
    });

    haulTest('clicking the dimmed backdrop closes it', (tester) async {
      await pumpHaul(tester, opener());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 590));
      await tester.pumpAndSettle();
      expect(find.text('Remove download?'), findsNothing);
    });

    haulTest('a dialog that is not dismissible ignores both', (tester) async {
      await pumpHaul(tester, opener(dismissible: false));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.tapAt(const Offset(5, 590));
      await tester.pumpAndSettle();
      expect(find.text('Remove download?'), findsOneWidget);
    });

    haulTest('its buttons work and close it', (tester) async {
      final log = <String>[];
      await pumpHaul(tester, opener(log: log));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(log, ['remove']);
      expect(find.text('Remove download?'), findsNothing);
    });

    haulTest('with Reduce Motion it appears in 120 ms or less', (tester) async {
      await pumpHaul(tester, opener(), reduceMotion: true);
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      final scale = tester.widget<ScaleTransition>(
        find
            .ancestor(
              of: find.text('Remove download?'),
              matching: find.byType(ScaleTransition),
            )
            .first,
      );
      expect(scale.scale.value, 1.0);
    });
  });
}
