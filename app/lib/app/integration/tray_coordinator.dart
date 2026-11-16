import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/setting_keys.dart';
import '../../data/settings_repository.dart';
import '../../services/system/tray_host.dart';
import '../cubits/throughput_cubit.dart';
import '../format.dart';

/// Ids of the menu bar menu's entries.
abstract final class TrayIds {
  static const summary = 'summary';
  static const show = 'show';
  static const add = 'add';
  static const pauseAll = 'pauseAll';
  static const resumeAll = 'resumeAll';
  static const quit = 'quit';
}

/// What the menu says for [activeCount] downloads at [speed] bytes a second.
List<TrayEntry> buildTrayEntries({
  required int activeCount,
  required double speed,
}) {
  final summary = activeCount == 0
      ? 'No active downloads'
      : '$activeCount downloading · ${formatSpeed(speed)}';
  return [
    TrayEntry(TrayIds.summary, summary, enabled: false),
    const TrayEntry.separator(),
    const TrayEntry(TrayIds.show, 'Show Haul'),
    const TrayEntry(TrayIds.add, 'Add URL…'),
    const TrayEntry.separator(),
    TrayEntry(TrayIds.pauseAll, 'Pause all', enabled: activeCount > 0),
    const TrayEntry(TrayIds.resumeAll, 'Resume all'),
    const TrayEntry.separator(),
    const TrayEntry(TrayIds.quit, 'Quit Haul'),
  ];
}

/// Keeps the menu bar icon's menu current and acts on its choices. The
/// throughput cubit ticks once a second, which is also the most the menu is
/// ever rewritten; an unchanged menu is not rewritten at all.
class TrayCoordinator {
  TrayCoordinator({
    required this.host,
    required StateStreamable<ThroughputState> throughput,
    required SettingsRepository settings,
    required this.onShow,
    required this.onAdd,
    required this.onPauseAll,
    required this.onResumeAll,
    required this.onQuit,
  }) : _throughput = throughput,
       _settings = settings {
    unawaited(host.show());
    _refresh();
    _subs.add(_throughput.stream.listen((_) => _refresh()));
    _subs.add(
      _settings
          .watch(Keys.showSpeedInMenuBar)
          .skip(1)
          .listen((_) => _refresh()),
    );
    _subs.add(host.selections.listen(_choose));
  }

  final TrayHost host;
  final StateStreamable<ThroughputState> _throughput;
  final SettingsRepository _settings;
  final VoidCallback onShow;
  final VoidCallback onAdd;
  final VoidCallback onPauseAll;
  final VoidCallback onResumeAll;
  final VoidCallback onQuit;
  final _subs = <StreamSubscription<Object?>>[];

  List<TrayEntry>? _lastEntries;
  String? _lastTitle;

  void _refresh() {
    final s = _throughput.state;
    final entries = buildTrayEntries(
      activeCount: s.activeCount,
      speed: s.speed,
    );
    final title = _settings.get(Keys.showSpeedInMenuBar) && s.activeCount > 0
        ? formatSpeed(s.speed)
        : null;
    if (listEquals(entries, _lastEntries) && title == _lastTitle) return;
    _lastEntries = entries;
    _lastTitle = title;
    unawaited(host.update(entries: entries, title: title));
  }

  void _choose(String id) {
    switch (id) {
      case TrayIds.show:
        onShow();
      case TrayIds.add:
        onAdd();
      case TrayIds.pauseAll:
        onPauseAll();
      case TrayIds.resumeAll:
        onResumeAll();
      case TrayIds.quit:
        onQuit();
    }
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await host.dispose();
  }
}
