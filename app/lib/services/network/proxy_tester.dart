import 'dart:async';
import 'dart:io';

import 'package:download_engine/download_engine.dart';

import '../../app/error_text.dart';

/// What came of trying a proxy.
class ProxyTestResult {
  const ProxyTestResult.ok() : ok = true, message = 'The proxy works';
  const ProxyTestResult.failed(this.message) : ok = false;

  final bool ok;

  /// Plain words, fit to show.
  final String message;
}

/// Tries a request through a proxy to see whether it works.
abstract class ProxyTester {
  Future<ProxyTestResult> test(ProxyConfig proxy);
}

/// Makes a real request through the proxy using the engine's own code, so a
/// pass here means a download will get through too.
class EngineProxyTester implements ProxyTester {
  EngineProxyTester({Uri? target, this.timeout = const Duration(seconds: 10)})
    : target = target ?? Uri.parse('https://www.apple.com/');

  /// A small page that is always there.
  final Uri target;
  final Duration timeout;

  @override
  Future<ProxyTestResult> test(ProxyConfig proxy) async {
    final client = HttpClient()..autoUncompress = false;
    try {
      await probe(
        DownloadRequest(id: 'proxy-test', url: target, saveDir: ''),
        client: client,
        network: NetworkConfig(proxy: proxy),
      ).timeout(timeout);
      return const ProxyTestResult.ok();
    } on DownloadError catch (e) {
      // Reaching the site is the point. A 404 or a refusal from the site
      // still went through the proxy.
      if (e.code == DownloadErrorCode.proxyAuth) {
        return const ProxyTestResult.failed(
          'The proxy needs a user name and password, or they are wrong',
        );
      }
      if (e.code == DownloadErrorCode.network) {
        return const ProxyTestResult.failed(
          'Could not connect through the proxy. Check the host and port',
        );
      }
      return const ProxyTestResult.ok();
    } on TimeoutException {
      return const ProxyTestResult.failed('The proxy took too long to answer');
    } on Object catch (_) {
      return ProxyTestResult.failed(plainError(null));
    } finally {
      client.close(force: true);
    }
  }
}
