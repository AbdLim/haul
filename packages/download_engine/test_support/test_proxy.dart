import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One request the proxy forwarded (or refused).
class ProxyLogEntry {
  ProxyLogEntry(this.url, this.range, this.proxyAuthorization, this.status);
  final Uri url;
  final String? range;
  final String? proxyAuthorization;
  int status;
}

/// A minimal forward proxy for plain HTTP, for engine tests. It can demand
/// Basic credentials (answering 407 otherwise) and logs every request.
class TestProxy {
  TestProxy._(this._server);

  final HttpServer _server;
  final _upstream = HttpClient()..autoUncompress = false;
  final List<ProxyLogEntry> log = [];

  /// When set, requests without matching `Proxy-Authorization` get a 407.
  String? requireUser;
  String? requirePassword;

  static Future<TestProxy> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final p = TestProxy._(server);
    server.listen(p._handle);
    return p;
  }

  int get port => _server.port;

  Future<void> close() async {
    _upstream.close(force: true);
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest req) async {
    final entry = ProxyLogEntry(
      req.uri,
      req.headers.value(HttpHeaders.rangeHeader),
      req.headers.value(HttpHeaders.proxyAuthorizationHeader),
      0,
    );
    log.add(entry);
    final res = req.response;

    if (requireUser != null) {
      final want =
          'Basic ${base64.encode(utf8.encode('$requireUser:$requirePassword'))}';
      if (entry.proxyAuthorization != want) {
        entry.status = 407;
        res.statusCode = 407;
        res.headers.set(
          HttpHeaders.proxyAuthenticateHeader,
          'Basic realm="haul-test"',
        );
        await res.close();
        return;
      }
    }
    if (!req.uri.isAbsolute) {
      entry.status = 400;
      res.statusCode = 400;
      await res.close();
      return;
    }

    try {
      final up = await _upstream.openUrl(req.method, req.uri);
      up.followRedirects = false;
      req.headers.forEach((name, values) {
        const hop = {
          'proxy-authorization',
          'proxy-connection',
          'connection',
          'host',
          'content-length',
          'transfer-encoding',
        };
        if (!hop.contains(name)) up.headers.set(name, values);
      });
      final upRes = await up.close();
      entry.status = upRes.statusCode;
      res.statusCode = upRes.statusCode;
      upRes.headers.forEach((name, values) {
        if (name != 'transfer-encoding' && name != 'connection') {
          res.headers.set(name, values);
        }
      });
      await res.addStream(upRes);
      await res.close();
    } on Object {
      // The client or origin went away mid-transfer.
      try {
        await res.close();
      } on Object {
        // Already closed.
      }
    }
  }
}
