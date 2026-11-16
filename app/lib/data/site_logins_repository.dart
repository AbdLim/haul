import 'package:download_engine/download_engine.dart';
import 'package:drift/drift.dart';

import '../services/system/secret_store.dart';
import 'database.dart';

/// A stored login as the UI sees it. The password is never part of it.
class SiteLoginEntry {
  const SiteLoginEntry(this.host, this.username);
  final String host;
  final String username;
}

/// Logins for sites that ask for HTTP authentication. The host and user name
/// are in the database; the password is only in the [SecretStore].
class SiteLoginsRepository {
  SiteLoginsRepository(this._db, this._secrets);

  final HaulDatabase _db;
  final SecretStore _secrets;

  static String normalize(String host) => host.trim().toLowerCase();

  Future<List<SiteLoginEntry>> all() async {
    final rows = await (_db.select(
      _db.siteLogins,
    )..orderBy([(t) => OrderingTerm.asc(t.host)])).get();
    return [for (final r in rows) SiteLoginEntry(r.host, r.username)];
  }

  Stream<List<SiteLoginEntry>> watchAll() {
    final query = _db.select(_db.siteLogins)
      ..orderBy([(t) => OrderingTerm.asc(t.host)]);
    return query.watch().map(
      (rows) => [for (final r in rows) SiteLoginEntry(r.host, r.username)],
    );
  }

  /// Adds a login or replaces the one for that host.
  Future<void> save(String host, String username, String password) async {
    final h = normalize(host);
    if (h.isEmpty) throw ArgumentError('A site login needs a host');
    // Secret first: a row without a password is worse than the reverse.
    await _secrets.write(siteLoginKey(h), password);
    await _db
        .into(_db.siteLogins)
        .insertOnConflictUpdate(
          SiteLoginsCompanion.insert(host: h, username: username),
        );
  }

  /// Changes the user name but keeps the stored password.
  Future<void> rename(String host, String username) =>
      (_db.update(_db.siteLogins)..where((t) => t.host.equals(normalize(host))))
          .write(SiteLoginsCompanion(username: Value(username)));

  /// Removes the row and the Keychain entry.
  Future<void> delete(String host) async {
    final h = normalize(host);
    await (_db.delete(_db.siteLogins)..where((t) => t.host.equals(h))).go();
    await _secrets.delete(siteLoginKey(h));
  }

  /// Only for sending to the engine or filling an edit box on request.
  Future<String?> password(String host) =>
      _secrets.read(siteLoginKey(normalize(host)));

  /// Host to login, for `NetworkConfig.siteLogins`. A row whose password has
  /// gone from the Keychain is left out.
  Future<Map<String, SiteLogin>> forEngine() async {
    final out = <String, SiteLogin>{};
    for (final e in await all()) {
      final pw = await password(e.host);
      if (pw != null) out[e.host] = SiteLogin(e.username, pw);
    }
    return out;
  }
}
