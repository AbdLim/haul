/// An HTTP proxy. SOCKS is not supported.
class ProxyConfig {
  const ProxyConfig({
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.bypass = const [],
  });

  final String host;
  final int port;
  final String? username;
  final String? password;

  /// Hosts that connect directly: exact names, or `*.example.com` for a
  /// domain and everything under it.
  final List<String> bypass;

  bool bypasses(String requestHost) {
    final h = requestHost.toLowerCase();
    for (final raw in bypass) {
      final rule = raw.trim().toLowerCase();
      if (rule.isEmpty) continue;
      if (rule.startsWith('*.')) {
        final suffix = rule.substring(1); // ".example.com"
        if (h.endsWith(suffix) || h == rule.substring(2)) return true;
      } else if (h == rule) {
        return true;
      }
    }
    return false;
  }

  Map<String, Object?> toJson() => {
    'host': host,
    'port': port,
    'username': username,
    'password': password,
    'bypass': bypass,
  };

  factory ProxyConfig.fromJson(Map<String, Object?> json) => ProxyConfig(
    host: json['host']! as String,
    port: json['port']! as int,
    username: json['username'] as String?,
    password: json['password'] as String?,
    bypass: (json['bypass']! as List<Object?>).cast<String>(),
  );
}

/// A user name and password for HTTP Basic authentication on one site.
class SiteLogin {
  const SiteLogin(this.username, this.password);
  final String username;
  final String password;

  Map<String, Object?> toJson() => {'username': username, 'password': password};

  factory SiteLogin.fromJson(Map<String, Object?> json) =>
      SiteLogin(json['username']! as String, json['password']! as String);
}

/// Everything the engine needs to know about the network. The app builds it
/// from settings and the Keychain; the engine never reads either.
class NetworkConfig {
  const NetworkConfig({
    this.proxy,
    this.siteLogins = const {},
    this.siteLimits = const {},
    this.defaultUserAgent,
  });

  /// Null means no proxy.
  final ProxyConfig? proxy;

  /// Host to login, for `Authorization: Basic`.
  final Map<String, SiteLogin> siteLogins;

  /// Host to the most connections a download from it may use.
  final Map<String, int> siteLimits;

  /// Used when a download has no user agent of its own.
  final String? defaultUserAgent;

  Map<String, Object?> toJson() => {
    'proxy': proxy?.toJson(),
    'siteLogins': {for (final e in siteLogins.entries) e.key: e.value.toJson()},
    'siteLimits': siteLimits,
    'defaultUserAgent': defaultUserAgent,
  };

  factory NetworkConfig.fromJson(Map<String, Object?> json) => NetworkConfig(
    proxy: json['proxy'] == null
        ? null
        : ProxyConfig.fromJson(json['proxy']! as Map<String, Object?>),
    siteLogins: {
      for (final e in (json['siteLogins']! as Map<Object?, Object?>).entries)
        e.key! as String: SiteLogin.fromJson(
          (e.value! as Map<Object?, Object?>).cast(),
        ),
    },
    siteLimits: (json['siteLimits']! as Map<Object?, Object?>).cast(),
    defaultUserAgent: json['defaultUserAgent'] as String?,
  );
}
