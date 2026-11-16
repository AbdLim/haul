import 'dart:async';

import 'package:download_engine/download_engine.dart';

import '../services/network/system_proxy.dart';
import '../services/system/secret_store.dart';
import 'downloads_repository.dart';
import 'setting_keys.dart';
import 'settings_repository.dart';
import 'site_logins_repository.dart';
import 'site_rules_repository.dart';

/// Builds the engine's network configuration (proxy, site logins, per-site
/// connection caps, default user agent) from settings and the Keychain, sends
/// it, and sends it again whenever any of them changes.
class NetworkSync {
  NetworkSync({
    required SettingsRepository settings,
    required SecretStore secrets,
    required SiteLoginsRepository logins,
    required SiteRulesRepository rules,
    required DownloadsRepository downloads,
    SystemProxyResolver? systemProxy,
    this.delay = const Duration(milliseconds: 150),
  }) : _settings = settings,
       _secrets = secrets,
       _logins = logins,
       _rules = rules,
       _downloads = downloads,
       _systemProxy = systemProxy {
    for (final key in [
      Keys.proxyMode,
      Keys.proxyHost,
      Keys.proxyPort,
      Keys.proxyUsername,
      Keys.proxyBypass,
      Keys.defaultUserAgent,
    ]) {
      _subs.add(_settings.watch(key).skip(1).listen((_) => schedule()));
    }
    _subs.add(_logins.watchAll().skip(1).listen((_) => schedule()));
    _subs.add(_rules.watchAll().skip(1).listen((_) => schedule()));
    schedule(now: true);
  }

  final SettingsRepository _settings;
  final SecretStore _secrets;
  final SiteLoginsRepository _logins;
  final SiteRulesRepository _rules;
  final DownloadsRepository _downloads;
  final SystemProxyResolver? _systemProxy;

  /// Changes made close together are sent once.
  final Duration delay;

  final _subs = <StreamSubscription<Object?>>[];
  Timer? _timer;
  var _disposed = false;
  Future<void> _chain = Future.value();

  /// What was last sent, for code that makes its own requests (the Add
  /// dialog's look at a link) and should see the same proxy, logins and
  /// user agent a download would.
  NetworkConfig latest = const NetworkConfig();

  /// A change to the proxy password, which is not a setting.
  void passwordChanged() => schedule();

  void schedule({bool now = false}) {
    _timer?.cancel();
    if (now) {
      _chain = _chain.then((_) => push());
      return;
    }
    _timer = Timer(delay, () => _chain = _chain.then((_) => push()));
  }

  /// The manual proxy as set in the settings, or null for "no proxy". Used by
  /// "Test proxy" too.
  Future<ProxyConfig?> manualProxy() async {
    final host = _settings.get(Keys.proxyHost)?.trim();
    final port = _settings.get(Keys.proxyPort);
    if (host == null || host.isEmpty || port == null) return null;
    final user = _settings.get(Keys.proxyUsername)?.trim();
    final hasUser = user != null && user.isNotEmpty;
    return ProxyConfig(
      host: host,
      port: port,
      username: hasUser ? user : null,
      password: hasUser ? await _secrets.read(proxyPasswordKey) : null,
      bypass: _settings.get(Keys.proxyBypass),
    );
  }

  Future<NetworkConfig> build() async {
    final ProxyConfig? proxy;
    switch (_settings.get(Keys.proxyMode)) {
      case ProxyMode.none:
        proxy = null;
      case ProxyMode.manual:
        proxy = await manualProxy();
      case ProxyMode.system:
        proxy = await _systemProxy?.resolve();
    }
    return NetworkConfig(
      proxy: proxy,
      siteLogins: await _logins.forEngine(),
      siteLimits: await _rules.connectionLimits(),
      defaultUserAgent: _settings.get(Keys.defaultUserAgent),
    );
  }

  Future<void> push() async {
    if (_disposed) return;
    final config = await build();
    if (_disposed) return;
    latest = config;
    _downloads.setNetwork(config);
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    await _chain;
  }
}
