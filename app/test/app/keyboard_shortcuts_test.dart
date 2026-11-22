import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/commands.dart';
import 'package:haul/app/cubits/downloads_cubit.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/app/keyboard_shortcuts.dart';

import '../support/test_deps.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ShellCubit shell;
  late DownloadsCubit downloads;
  late HaulCommands commands;
  late dynamic deps;
  var toggledDetail = 0;

  HaulShortcuts shortcuts() => HaulShortcuts(
    commands: commands,
    onToggleDetail: () => toggledDetail++,
    child: const SizedBox(),
  );

  /// The key that runs [trigger] with the modifiers, in [bindings].
  SingleActivator keyFor(
    Map<ShortcutActivator, VoidCallback> bindings,
    LogicalKeyboardKey trigger, {
    bool shift = false,
  }) => bindings.keys.cast<SingleActivator>().singleWhere(
    (a) => a.trigger == trigger && a.shift == shift,
  );

  setUp(() async {
    final t = await makeTestDeps();
    deps = t.deps;
    shell = ShellCubit();
    downloads = DownloadsCubit(t.deps.downloads, t.deps.categories);
    commands = HaulCommands(shell: shell, downloads: downloads);
    toggledDetail = 0;
  });
  tearDown(() async {
    await shell.close();
    await downloads.close();
    await deps.dispose();
  });

  test('the menu bar commands are reachable under Control', () {
    final bindings = shortcuts().bindings();
    expect(bindings, hasLength(10));
    for (final a in bindings.keys.cast<SingleActivator>()) {
      expect(a.control, isTrue, reason: '${a.trigger}');
      expect(a.meta, isFalse, reason: '${a.trigger}');
    }
    expect(
      [
        for (final a in bindings.keys.cast<SingleActivator>())
          (a.trigger, a.shift),
      ],
      containsAll([
        (LogicalKeyboardKey.comma, false),
        (LogicalKeyboardKey.keyN, false),
        (LogicalKeyboardKey.keyP, true),
        (LogicalKeyboardKey.keyR, true),
        (LogicalKeyboardKey.keyX, false),
        (LogicalKeyboardKey.keyC, false),
        (LogicalKeyboardKey.keyV, false),
        (LogicalKeyboardKey.keyA, false),
        (LogicalKeyboardKey.digit1, false),
        (LogicalKeyboardKey.keyI, false),
      ]),
    );
  });

  test('Shift separates Pause All and Resume All, as on the Mac', () {
    final bindings = shortcuts().bindings();
    expect(
      bindings.keys.whereType<SingleActivator>().where(
        (a) => a.trigger == LogicalKeyboardKey.keyP && !a.shift,
      ),
      isEmpty,
    );
    expect(
      bindings[keyFor(bindings, LogicalKeyboardKey.keyP, shift: true)],
      isNotNull,
    );
  });

  test('the shortcuts do what the menu items do', () {
    final bindings = shortcuts().bindings();
    bindings[keyFor(bindings, LogicalKeyboardKey.comma)]!();
    expect(shell.state.section, MainSection.settings);

    bindings[keyFor(bindings, LogicalKeyboardKey.keyN)]!();
    expect(shell.state.addDialogOpen, isTrue);

    bindings[keyFor(bindings, LogicalKeyboardKey.digit1)]!();
    expect(shell.state.section, MainSection.downloads);
  });

  test('Toggle Details is bound only where the app can toggle it', () {
    final bindings = shortcuts().bindings();
    bindings[keyFor(bindings, LogicalKeyboardKey.keyI)]!();
    expect(toggledDetail, 1);

    final bare = HaulShortcuts(
      commands: commands,
      child: const SizedBox(),
    ).bindings();
    expect(
      bare.keys.whereType<SingleActivator>().where(
        (a) => a.trigger == LogicalKeyboardKey.keyI,
      ),
      isEmpty,
    );
  });

  testWidgets('the shortcuts are installed under the widget tree', (
    tester,
  ) async {
    await tester.pumpWidget(shortcuts());
    expect(find.byType(CallbackShortcuts), findsOneWidget);
  });
}
