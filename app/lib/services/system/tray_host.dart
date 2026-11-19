import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';

/// One line of the menu bar menu.
class TrayEntry {
  const TrayEntry(this.id, this.label, {this.enabled = true});
  const TrayEntry.separator() : id = null, label = '', enabled = false;

  /// Null for a separator.
  final String? id;
  final String label;
  final bool enabled;

  bool get isSeparator => id == null;

  @override
  bool operator ==(Object other) =>
      other is TrayEntry &&
      other.id == id &&
      other.label == label &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(id, label, enabled);
}

/// The menu bar icon and its menu.
abstract class TrayHost {
  /// Puts the icon in the menu bar.
  Future<void> show();

  /// Replaces the menu and the short text beside the icon (null for none).
  Future<void> update({required List<TrayEntry> entries, String? title});

  /// The ids of entries the person chose.
  Stream<String> get selections;

  Future<void> dispose();

  static TrayHost get current {
    if (Platform.isMacOS || Platform.isWindows) return TrayManagerHost();
    throw UnsupportedError('No tray for ${Platform.operatingSystem}');
  }
}

class TrayManagerHost with TrayListener implements TrayHost {
  final _selected = StreamController<String>.broadcast();

  @override
  Stream<String> get selections => _selected.stream;

  @override
  Future<void> show() async {
    trayManager.addListener(this);
    if (Platform.isMacOS) {
      // A template image: macOS tints it for light and dark menu bars.
      await trayManager.setIcon(
        'assets/brand/menubar/haulMenubarTemplate@2x.png',
        isTemplate: true,
      );
    } else {
      await trayManager.setIcon(await _iconFile());
      await trayManager.setToolTip('Haul');
    }
  }

  @override
  Future<void> update({required List<TrayEntry> entries, String? title}) async {
    if (Platform.isMacOS) {
      await trayManager.setTitle(title ?? '');
    } else {
      // The notification area has no room for text, so the speed goes in the
      // tooltip, where the pointer finds it.
      await trayManager.setToolTip(title == null ? 'Haul' : 'Haul - $title');
    }
    await trayManager.setContextMenu(
      Menu(
        items: [
          for (final e in entries)
            if (e.isSeparator)
              MenuItem.separator()
            else
              MenuItem(key: e.id, label: e.label, disabled: !e.enabled),
        ],
      ),
    );
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key;
    if (key != null) _selected.add(key);
  }

  @override
  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
    await _selected.close();
  }
}

/// The notification area takes a file on disk, not Flutter's asset bundle, so
/// the bundled icon is written out once and that copy is used from then on.
Future<String> _iconFile() async {
  final support = await getApplicationSupportDirectory();
  final file = File(p.join(support.path, 'tray.ico'));
  if (!file.existsSync()) {
    final data = await rootBundle.load('assets/brand/windows/haulTray.ico');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }
  return file.path;
}

class FakeTrayHost implements TrayHost {
  bool shown = false;
  int updates = 0;
  List<TrayEntry> entries = const [];
  String? title;
  final _selected = StreamController<String>.broadcast();

  void choose(String id) => _selected.add(id);

  @override
  Stream<String> get selections => _selected.stream;

  @override
  Future<void> show() async => shown = true;

  @override
  Future<void> update({required List<TrayEntry> entries, String? title}) async {
    updates++;
    this.entries = entries;
    this.title = title;
  }

  @override
  Future<void> dispose() async {}
}
