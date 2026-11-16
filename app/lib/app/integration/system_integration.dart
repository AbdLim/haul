import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/setting_keys.dart';
import '../commands.dart';
import '../cubits/downloads_cubit.dart';
import '../cubits/throughput_cubit.dart';
import '../dependencies.dart';
import 'event_alerts.dart';
import 'power_coordinator.dart';
import 'quit_guard.dart';
import 'tray_coordinator.dart';

/// Everything that lets Haul behave like a Mac app that lives in the menu bar:
/// the hidden window, the menu bar icon, banners and sounds, the sleep lock
/// and the login item. Built once by the app; each part is skipped when its
/// service is missing, so tests can pick what they need.
class SystemIntegration {
  SystemIntegration({
    required AppDependencies deps,
    required DownloadsCubit downloads,
    required ThroughputCubit throughput,
    required HaulCommands commands,
    required GlobalKey<NavigatorState> navigator,
  }) : _deps = deps {
    final window = deps.window;
    final tray = deps.tray;
    final notifier = deps.notifier;
    final sleep = deps.sleepBlocker;
    final login = deps.loginItem;

    if (window != null) {
      quitGuard = QuitGuard(
        window: window,
        downloads: downloads,
        navigator: navigator,
        beforeQuit: _shutDown,
      );
      unawaited(_hideIfStartedHidden());
    }
    if (tray != null && window != null) {
      this.tray = TrayCoordinator(
        host: tray,
        throughput: throughput,
        settings: deps.settings,
        onShow: window.show,
        onAdd: () {
          window.show();
          commands.newDownload();
        },
        onPauseAll: commands.pauseAll,
        onResumeAll: commands.resumeAll,
        onQuit: () => quitGuard!.requestQuit(),
      );
    }
    if (notifier != null) {
      alerts = EventAlerts(
        downloads: downloads,
        settings: deps.settings,
        notifier: notifier,
        platform: deps.platform,
        sounds: deps.sounds,
      );
    }
    if (sleep != null && login != null) {
      power = PowerCoordinator(
        throughput: throughput,
        settings: deps.settings,
        sleep: sleep,
        loginItem: login,
      );
    }
  }

  final AppDependencies _deps;
  QuitGuard? quitGuard;
  TrayCoordinator? tray;
  EventAlerts? alerts;
  PowerCoordinator? power;

  Future<void> _hideIfStartedHidden() async {
    final window = _deps.window!;
    final atLogin = await window.startedHidden();
    if (atLogin || _deps.settings.get(Keys.startHidden)) await window.hide();
  }

  /// Stops the engine and saves progress before the process ends.
  Future<void> _shutDown() async {
    try {
      await _deps.dispose().timeout(const Duration(seconds: 3));
    } on Object {
      // Quitting must not hang on a slow disk.
    }
  }

  Future<void> dispose() async {
    await quitGuard?.dispose();
    await tray?.dispose();
    await alerts?.dispose();
    await power?.dispose();
  }
}
