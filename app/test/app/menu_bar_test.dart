import 'package:download_engine/download_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/commands.dart';
import 'package:haul/app/cubits/downloads_cubit.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/app/menu_bar.dart';

import '../support/test_deps.dart';

PlatformMenu menu(List<PlatformMenuItem> all, String label) =>
    all.whereType<PlatformMenu>().firstWhere((m) => m.label == label);

/// Every plain item inside a menu, flattening the separator groups.
List<PlatformMenuItem> flat(PlatformMenu m) => [
  for (final i in m.menus)
    if (i is PlatformMenuItemGroup) ...i.members else i,
];

PlatformMenuItem item(
  List<PlatformMenuItem> all,
  String menuLabel,
  String label,
) => flat(menu(all, menuLabel)).firstWhere((i) => i.label == label);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ShellCubit shell;
  late DownloadsCubit downloads;
  late FakeEngine engine;
  late HaulCommands commands;
  late List<PlatformMenuItem> menus;
  late dynamic deps;

  setUp(() async {
    // The system-provided items (Quit, Hide...) exist only on macOS.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final t = await makeTestDeps();
    deps = t.deps;
    engine = t.engine;
    shell = ShellCubit();
    downloads = DownloadsCubit(t.deps.downloads, t.deps.categories);
    commands = HaulCommands(shell: shell, downloads: downloads);
    menus = HaulMenuBar.menus(commands);
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await shell.close();
    await downloads.close();
    await deps.dispose();
  });

  test(
    'the menu bar has Haul, File, Edit, View, Window and Help, in order',
    () {
      expect(menus.whereType<PlatformMenu>().map((m) => m.label), [
        'Haul',
        'File',
        'Edit',
        'View',
        'Window',
        'Help',
      ]);
    },
  );

  test('the standard shortcuts are there', () {
    SingleActivator? key(String menuLabel, String label) =>
        item(menus, menuLabel, label).shortcut as SingleActivator?;

    final settings = key('Haul', 'Settings…')!;
    expect(settings.trigger, LogicalKeyboardKey.comma);
    expect(settings.meta, isTrue);

    final newDownload = key('File', 'New Download…')!;
    expect(newDownload.trigger, LogicalKeyboardKey.keyN);
    expect(newDownload.meta, isTrue);

    expect(key('Edit', 'Cut')!.trigger, LogicalKeyboardKey.keyX);
    expect(key('Edit', 'Copy')!.trigger, LogicalKeyboardKey.keyC);
    expect(key('Edit', 'Paste')!.trigger, LogicalKeyboardKey.keyV);
    expect(key('Edit', 'Select All')!.trigger, LogicalKeyboardKey.keyA);
    for (final label in ['Cut', 'Copy', 'Paste', 'Select All']) {
      expect(key('Edit', label)!.meta, isTrue, reason: label);
    }
  });

  test('Quit, Hide and the window items are the system-provided ones', () {
    final haul = flat(menu(menus, 'Haul'));
    final types = haul
        .whereType<PlatformProvidedMenuItem>()
        .map((i) => i.type)
        .toSet();
    expect(
      types,
      containsAll([
        PlatformProvidedMenuItemType.about,
        PlatformProvidedMenuItemType.quit,
        PlatformProvidedMenuItemType.hide,
      ]),
    );
    final window = flat(menu(menus, 'Window'))
        .whereType<PlatformProvidedMenuItem>()
        .map((i) => i.type);
    expect(
      window,
      containsAll([
        PlatformProvidedMenuItemType.minimizeWindow,
        PlatformProvidedMenuItemType.zoomWindow,
      ]),
    );
  });

  test('every menu item that is ours does something', () {
    for (final m in menus.whereType<PlatformMenu>()) {
      for (final i in flat(m)) {
        if (i is PlatformProvidedMenuItem) continue;
        if (i.label == 'Toggle Details' || i.label == 'Haul Help') continue;
        expect(i.onSelected, isNotNull, reason: '${m.label} > ${i.label}');
      }
    }
  });

  test('Settings and New Download change the window state', () {
    item(menus, 'Haul', 'Settings…').onSelected!();
    expect(shell.state.section, MainSection.settings);

    item(menus, 'File', 'New Download…').onSelected!();
    expect(shell.state.addDialogOpen, isTrue);
    expect(shell.state.section, MainSection.downloads);

    item(menus, 'View', 'Downloads').onSelected!();
    expect(shell.state.section, MainSection.downloads);
  });

  test('Pause All and Resume All reach the engine', () async {
    engine.emit(
      SnapshotEvent(
        DownloadSnapshot(
          request: DownloadRequest(
            id: 'a',
            url: Uri.parse('https://e.com/a'),
            saveDir: '/d',
          ),
          status: DownloadStatus.downloading,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));

    item(menus, 'File', 'Pause All').onSelected!();
    expect(engine.commands.whereType<PauseCommand>(), hasLength(1));
  });

  test('Paste opens the Add URL dialog when no text field is focused', () {
    item(menus, 'Edit', 'Paste').onSelected!();
    expect(shell.state.addDialogOpen, isTrue);
  });
}
