import 'dart:io';

import 'package:download_engine/download_engine.dart';

import 'system_proxy.dart';

/// Where Windows keeps the proxy settings for the whole machine.
const internetSettingsKey =
    r'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings';

/// Asks `reg query` for the Internet Settings, which is what "use the system
/// proxy" means on Windows.
class RegistrySystemProxyResolver implements SystemProxyResolver {
  const RegistrySystemProxyResolver();

  @override
  Future<ProxyConfig?> resolve() async {
    try {
      final r = await Process.run('reg.exe', ['query', internetSettingsKey]);
      if (r.exitCode != 0) return null;
      return parseWindowsProxy(r.stdout as String);
    } on ProcessException {
      return null;
    }
  }
}

/// Turns a `reg query` dump of Internet Settings into a proxy.
///
/// The `ProxyServer` value is either `host:port` or a list such as
/// `http=host:port;https=host:port`. An HTTP proxy wins; failing that, an
/// HTTPS one is used (it is still an HTTP proxy that tunnels). SOCKS and
/// auto-configuration scripts are not supported.
ProxyConfig? parseWindowsProxy(String output) {
  final values = parseRegQuery(output);
  final enabled = values['ProxyEnable']?.trim();
  if (enabled != '0x1' && enabled != '1') return null;

  final server = values['ProxyServer']?.trim();
  if (server == null || server.isEmpty) return null;

  final host = _entryFor(server, 'http') ?? _entryFor(server, 'https');
  if (host == null) return null;

  return ProxyConfig(
    host: host.host,
    port: host.port,
    bypass: parseWindowsBypass(values['ProxyOverride'] ?? ''),
  );
}

/// The `name:port` entries of a `reg query` dump, by value name.
Map<String, String> parseRegQuery(String output) {
  final values = <String, String>{};
  for (final line in output.split('\n')) {
    final m = RegExp(r'^\s{4}(\S+)\s+REG_[A-Z_]+\s+(.*)$').firstMatch(line);
    if (m != null) values[m.group(1)!] = m.group(2)!.trimRight();
  }
  return values;
}

/// The hosts in a `ProxyServer` value that connect through [scheme], or null
/// when the value names no scheme at all.
({String host, int port})? _entryFor(String value, String scheme) {
  if (!value.contains('=')) return _hostAndPort(value);
  for (final part in value.split(';')) {
    final eq = part.indexOf('=');
    if (eq < 0) continue;
    if (part.substring(0, eq).trim().toLowerCase() != scheme) continue;
    return _hostAndPort(part.substring(eq + 1));
  }
  return null;
}

({String host, int port})? _hostAndPort(String value) {
  final text = value.trim();
  final colon = text.lastIndexOf(':');
  if (colon <= 0) return null;
  final host = text.substring(0, colon).trim();
  final port = int.tryParse(text.substring(colon + 1).trim());
  if (host.isEmpty || port == null) return null;
  return (host: host, port: port);
}

/// The hosts in a `ProxyOverride` value, which is a semicolon list. Windows'
/// own `"<local>"` entry means "names without a dot", which the engine reads
/// as no rule at all, so it is left out.
List<String> parseWindowsBypass(String value) => [
  for (final part in value.split(';'))
    if (part.trim().isNotEmpty && part.trim().toLowerCase() != '<local>')
      part.trim(),
];
