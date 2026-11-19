import 'dart:io';

import 'package:download_engine/download_engine.dart';

import 'windows_system_proxy.dart';

/// Reads the system's own proxy setting, which is what "use the system proxy"
/// means. The engine only takes a manual proxy, so the app resolves the
/// system one and sends the result.
abstract class SystemProxyResolver {
  /// Null when the system uses no HTTP proxy.
  Future<ProxyConfig?> resolve();

  static SystemProxyResolver get current {
    if (Platform.isMacOS) return const ScutilSystemProxyResolver();
    if (Platform.isWindows) return const RegistrySystemProxyResolver();
    throw UnsupportedError('No proxy setting for ${Platform.operatingSystem}');
  }
}

/// Asks `scutil --proxy`, which prints the active network's proxy settings.
class ScutilSystemProxyResolver implements SystemProxyResolver {
  const ScutilSystemProxyResolver();

  @override
  Future<ProxyConfig?> resolve() async {
    try {
      final r = await Process.run('scutil', ['--proxy']);
      if (r.exitCode != 0) return null;
      return parseScutilProxy(r.stdout as String);
    } on ProcessException {
      return null;
    }
  }
}

/// Turns `scutil --proxy` output into a proxy. An HTTP proxy wins; failing
/// that, an HTTPS one is used (it is still an HTTP proxy that tunnels). SOCKS
/// and auto-configuration scripts are not supported.
ProxyConfig? parseScutilProxy(String output) {
  final values = <String, String>{};
  final exceptions = <String>[];
  var inExceptions = false;
  for (final raw in output.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('ExceptionsList')) {
      inExceptions = true;
      continue;
    }
    if (inExceptions) {
      if (line.startsWith('}')) {
        inExceptions = false;
        continue;
      }
      final m = RegExp(r'^\d+\s*:\s*(.+)$').firstMatch(line);
      if (m != null) exceptions.add(m.group(1)!.trim());
      continue;
    }
    final m = RegExp(r'^(\w+)\s*:\s*(.+)$').firstMatch(line);
    if (m != null) values[m.group(1)!] = m.group(2)!.trim();
  }

  for (final kind in ['HTTP', 'HTTPS']) {
    if (values['${kind}Enable'] != '1') continue;
    final host = values['${kind}Proxy'];
    final port = int.tryParse(values['${kind}Port'] ?? '');
    if (host == null || host.isEmpty || port == null) continue;
    return ProxyConfig(host: host, port: port, bypass: exceptions);
  }
  return null;
}
