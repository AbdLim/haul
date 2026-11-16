import 'dart:async';

import 'downloads_repository.dart';
import 'setting_keys.dart';
import 'settings_repository.dart';

/// Keeps the engine's limits in step with the settings: now, and on every
/// change afterwards.
class SettingsEngineSync {
  SettingsEngineSync(this._settings, this._downloads) {
    push();
    for (final key in [
      Keys.maxConnections,
      Keys.maxConcurrentDownloads,
      Keys.speedLimitEnabled,
      Keys.speedLimitBytesPerSec,
    ]) {
      // `watch` emits the current value first; `push` ran already, so skip it.
      _subs.add(_settings.watch(key).skip(1).listen((_) => push()));
    }
  }

  final SettingsRepository _settings;
  final DownloadsRepository _downloads;
  final _subs = <StreamSubscription<Object?>>[];

  void push() {
    final limited = _settings.get(Keys.speedLimitEnabled);
    _downloads.setLimits(
      maxConcurrentDownloads: _settings.get(Keys.maxConcurrentDownloads),
      maxConnections: _settings.get(Keys.maxConnections),
      // 0 means unlimited to the engine.
      speedLimitBytesPerSec: limited
          ? _settings.get(Keys.speedLimitBytesPerSec)
          : 0,
    );
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
  }
}
