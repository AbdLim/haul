import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'commands.dart';
import 'keyboard_shortcuts.dart';

/// The native macOS menu bar: Haul, File, Edit, View, Window and Help, with
/// the usual Command shortcuts. Elsewhere, where there is no menu bar to hang
/// them on, it is [HaulShortcuts] instead: the same commands under Control.
class HaulMenuBar extends StatelessWidget {
  const HaulMenuBar({required this.commands, required this.child, super.key});

  final HaulCommands commands;
  final Widget child;

  static SingleActivator cmd(LogicalKeyboardKey key, {bool shift = false}) =>
      SingleActivator(key, meta: true, shift: shift);

  /// A system-provided item (About, Quit, Minimize...), or nothing on a
  /// platform that has no such item, where asking for one would throw.
  static List<PlatformMenuItem> _provided(
    List<PlatformProvidedMenuItemType> types,
  ) => [
    for (final t in types)
      if (PlatformProvidedMenuItem.hasMenu(t))
        PlatformProvidedMenuItem(type: t),
  ];

  /// A separator-delimited group, left out when it would be empty.
  static List<PlatformMenuItem> _group(List<PlatformMenuItem> members) =>
      members.isEmpty ? const [] : [PlatformMenuItemGroup(members: members)];

  /// Separated out so tests can inspect the menus without a platform.
  static List<PlatformMenuItem> menus(
    HaulCommands c, {
    VoidCallback? onToggleDetail,
    VoidCallback? onHelp,
    bool showGallery = false,
  }) => [
    PlatformMenu(
      label: 'Haul',
      menus: [
        ..._provided([PlatformProvidedMenuItemType.about]),
        ..._group([
          PlatformMenuItem(
            label: 'Settings…',
            shortcut: cmd(LogicalKeyboardKey.comma),
            onSelected: c.openSettings,
          ),
        ]),
        ..._group(_provided([PlatformProvidedMenuItemType.servicesSubmenu])),
        ..._group(
          _provided([
            PlatformProvidedMenuItemType.hide,
            PlatformProvidedMenuItemType.hideOtherApplications,
            PlatformProvidedMenuItemType.showAllApplications,
          ]),
        ),
        ..._group(_provided([PlatformProvidedMenuItemType.quit])),
      ],
    ),
    PlatformMenu(
      label: 'File',
      menus: [
        PlatformMenuItem(
          label: 'New Download…',
          shortcut: cmd(LogicalKeyboardKey.keyN),
          onSelected: c.newDownload,
        ),
        ..._group([
          PlatformMenuItem(
            label: 'Pause All',
            shortcut: cmd(LogicalKeyboardKey.keyP, shift: true),
            onSelected: c.pauseAll,
          ),
          PlatformMenuItem(
            label: 'Resume All',
            shortcut: cmd(LogicalKeyboardKey.keyR, shift: true),
            onSelected: c.resumeAll,
          ),
        ]),
      ],
    ),
    PlatformMenu(
      label: 'Edit',
      menus: [
        PlatformMenuItem(
          label: 'Cut',
          shortcut: cmd(LogicalKeyboardKey.keyX),
          onSelected: c.cut,
        ),
        PlatformMenuItem(
          label: 'Copy',
          shortcut: cmd(LogicalKeyboardKey.keyC),
          onSelected: c.copy,
        ),
        PlatformMenuItem(
          label: 'Paste',
          shortcut: cmd(LogicalKeyboardKey.keyV),
          onSelected: c.paste,
        ),
        PlatformMenuItem(
          label: 'Select All',
          shortcut: cmd(LogicalKeyboardKey.keyA),
          onSelected: c.selectAll,
        ),
      ],
    ),
    PlatformMenu(
      label: 'View',
      menus: [
        PlatformMenuItem(
          label: 'Downloads',
          shortcut: cmd(LogicalKeyboardKey.digit1),
          onSelected: c.showDownloads,
        ),
        PlatformMenuItem(
          label: 'Toggle Details',
          shortcut: cmd(LogicalKeyboardKey.keyI),
          onSelected: onToggleDetail,
        ),
        ..._group([
          if (showGallery)
            PlatformMenuItem(
              label: 'Component Gallery',
              onSelected: c.openGallery,
            ),
        ]),
        ..._group(_provided([PlatformProvidedMenuItemType.toggleFullScreen])),
      ],
    ),
    PlatformMenu(
      label: 'Window',
      menus: [
        ..._provided([
          PlatformProvidedMenuItemType.minimizeWindow,
          PlatformProvidedMenuItemType.zoomWindow,
        ]),
        ..._group(
          _provided([PlatformProvidedMenuItemType.arrangeWindowsInFront]),
        ),
      ],
    ),
    PlatformMenu(
      label: 'Help',
      menus: [PlatformMenuItem(label: 'Haul Help', onSelected: onHelp)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Windows has no menu bar to hang the shortcuts on, so it gets the same
    // commands as plain Control shortcuts.
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return HaulShortcuts(commands: commands, child: child);
    }
    return PlatformMenuBar(
      menus: menus(commands, showGallery: kDebugMode),
      child: child,
    );
  }
}
