import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/setting_keys.dart';
import '../../data/settings_repository.dart';
import '../../services/system/login_item.dart';
import '../../services/system/sleep_blocker.dart';
import '../cubits/throughput_cubit.dart';

/// Holds the Mac awake while a download runs (if the setting allows), and
/// keeps the login item in step with the "Open at login" setting.
class PowerCoordinator {
  PowerCoordinator({
    required StateStreamable<ThroughputState> throughput,
    required SettingsRepository settings,
    required SleepBlocker sleep,
    required LoginItem loginItem,
  }) : _throughput = throughput,
       _settings = settings,
       _sleep = sleep,
       _login = loginItem {
    _apply();
    _subs.add(_throughput.stream.listen((_) => _apply()));
    _subs.add(_settings.watch(Keys.keepAwake).skip(1).listen((_) => _apply()));
    unawaited(_syncLogin(_settings.get(Keys.launchAtLogin)));
    _subs.add(_settings.watch(Keys.launchAtLogin).skip(1).listen(_syncLogin));
  }

  final StateStreamable<ThroughputState> _throughput;
  final SettingsRepository _settings;
  final SleepBlocker _sleep;
  final LoginItem _login;
  final _subs = <StreamSubscription<Object?>>[];

  void _apply() {
    final wanted =
        _settings.get(Keys.keepAwake) && _throughput.state.activeCount > 0;
    unawaited(wanted ? _sleep.hold() : _sleep.release());
  }

  Future<void> _syncLogin(bool wanted) async {
    try {
      if (await _login.isEnabled() != wanted) await _login.setEnabled(wanted);
    } on Object {
      // The login item is a convenience; failing to write it must not crash.
    }
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _sleep.release();
  }
}
