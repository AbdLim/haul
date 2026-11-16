import 'dart:async';
import 'dart:math';

import 'database.dart';
import 'setting_key.dart';
import 'setting_keys.dart';

/// Typed access to the `settings` table.
///
/// All rows are read once at start-up and kept in memory, so reads are
/// instant and every change is written straight to the database.
class SettingsRepository {
  SettingsRepository._(this._db, this._cache);

  final HaulDatabase _db;
  final Map<String, String> _cache;
  final _controllers = <String, StreamController<Object?>>{};

  static Future<SettingsRepository> open(HaulDatabase db) async {
    final rows = await db.select(db.settings).get();
    return SettingsRepository._(db, {for (final r in rows) r.key: r.value});
  }

  /// The current value, or the key's default if it was never set.
  T get<T>(SettingKey<T> key) => key.fromStored(_cache[key.name]);

  /// The current value now, then every change. Setting the same value again
  /// does not emit.
  Stream<T> watch<T>(SettingKey<T> key) {
    final controller = _controllers.putIfAbsent(
      key.name,
      () => StreamController<Object?>.broadcast(),
    );
    late final StreamController<T> out;
    StreamSubscription<Object?>? sub;
    out = StreamController<T>(
      onListen: () {
        out.add(get(key));
        sub = controller.stream.listen((v) => out.add(v as T));
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  Future<void> set<T>(SettingKey<T> key, T value) async {
    final stored = key.toStored(value);
    // Compare with what readers currently see, which for a setting that was
    // never stored is its default.
    final changed = key.toStored(get(key)) != stored;
    if (_cache[key.name] != stored) {
      _cache[key.name] = stored;
      await _db
          .into(_db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(key: key.name, value: stored),
          );
    }
    if (changed) _controllers[key.name]?.add(value);
  }

  /// Puts the given keys back to their defaults ("Reset this pane").
  Future<void> reset(Iterable<SettingKey<Object?>> keys) async {
    for (final key in keys) {
      await _reset(key);
    }
  }

  Future<void> _reset<T>(SettingKey<T> key) async {
    if (!_cache.containsKey(key.name)) return;
    _cache.remove(key.name);
    await (_db.delete(_db.settings)..where((t) => t.key.equals(key.name))).go();
    _controllers[key.name]?.add(key.defaultValue);
  }

  /// The token a browser extension must send to hand a download to Haul.
  /// Made once, from 32 random bytes, the first time it is needed.
  Future<String> ensureBridgeToken() async {
    final existing = get(Keys.bridgeToken);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final token = [
      for (var i = 0; i < 32; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    await set(Keys.bridgeToken, token);
    return token;
  }

  Future<void> dispose() async {
    for (final c in _controllers.values) {
      await c.close();
    }
  }
}
