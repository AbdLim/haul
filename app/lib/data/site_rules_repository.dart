import 'package:drift/drift.dart';

import 'database.dart';

class SiteRule {
  const SiteRule({
    required this.host,
    this.maxConnections,
    this.neverIntercept = false,
  });

  final String host;

  /// The most connections a download from this host may use, or null for no
  /// cap.
  final int? maxConnections;

  /// Haul never takes over browser downloads from this host.
  final bool neverIntercept;
}

/// Per-site connection caps and the list of sites Haul never intercepts.
class SiteRulesRepository {
  SiteRulesRepository(this._db);

  final HaulDatabase _db;

  static String normalize(String host) => host.trim().toLowerCase();

  /// The host in what a person typed or pasted: `https://Example.com/a` and
  /// `example.com` both give `example.com`.
  static String hostFrom(String text) {
    final t = text.trim();
    final uri = Uri.tryParse(t.contains('://') ? t : 'https://$t');
    final host = uri?.host ?? '';
    return normalize(host.isEmpty ? t : host);
  }

  Future<List<SiteRule>> all() async {
    final rows = await (_db.select(
      _db.siteRules,
    )..orderBy([(t) => OrderingTerm.asc(t.host)])).get();
    return [for (final r in rows) _from(r)];
  }

  Stream<List<SiteRule>> watchAll() {
    final query = _db.select(_db.siteRules)
      ..orderBy([(t) => OrderingTerm.asc(t.host)]);
    return query.watch().map((rows) => [for (final r in rows) _from(r)]);
  }

  Future<void> save(SiteRule rule) async {
    final host = normalize(rule.host);
    if (host.isEmpty) throw ArgumentError('A site rule needs a host');
    final cap = rule.maxConnections;
    if (cap == null && !rule.neverIntercept) {
      // Nothing left to remember about this host.
      await delete(host);
      return;
    }
    await _db
        .into(_db.siteRules)
        .insertOnConflictUpdate(
          SiteRulesCompanion.insert(
            host: host,
            maxConnections: Value(cap),
            neverIntercept: Value(rule.neverIntercept),
          ),
        );
  }

  Future<void> delete(String host) => (_db.delete(
    _db.siteRules,
  )..where((t) => t.host.equals(normalize(host)))).go();

  /// For the engine's `NetworkConfig.siteLimits`.
  Future<Map<String, int>> connectionLimits() async => {
    for (final r in await all())
      if (r.maxConnections != null && r.maxConnections! >= 1)
        r.host: r.maxConnections!,
  };

  /// For the browser extension's config: hosts it must leave alone.
  Future<List<String>> excludedHosts() async => [
    for (final r in await all())
      if (r.neverIntercept) r.host,
  ];

  SiteRule _from(SiteRuleRow r) => SiteRule(
    host: r.host,
    maxConnections: r.maxConnections,
    neverIntercept: r.neverIntercept,
  );
}
