import 'dart:convert';
import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/dependencies.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/data/site_rules_repository.dart';
import 'package:haul/services/bridge/bridge_controller.dart';
import 'package:haul/services/bridge/bridge_server.dart';
import 'package:haul/services/bridge/browser_intake.dart';

import '../support/test_deps.dart';

const _token = 'abc123';

class Reply {
  Reply(this.status, this.body, this.headers);
  final int status;
  final Map<String, Object?> body;
  final HttpHeaders headers;
}

void main() {
  late AppHarness h;

  setUp(() async => h = await AppHarness.create());
  tearDown(() => h.close());

  group('routes', () {
    test('ping needs no token', () async {
      final r = await h.get('/v1/ping');
      expect(r.status, 200);
      expect(r.body, {'app': 'Haul', 'version': '1.0.0', 'protocol': 1});
    });

    test(
      'a valid post is accepted and stored with the browser headers',
      () async {
        final r = await h.post({
          'url': 'https://example.com/file.zip',
          'finalUrl': 'https://cdn.example.com/file.zip?sig=abc',
          'fileName': 'file.zip',
          'referrer': 'https://example.com/downloads',
          'userAgent': 'Mozilla/5.0 test',
          'cookies': 'session=abc; theme=dark',
          'mimeType': 'application/zip',
          'fileSize': 104857600,
          'source': 'chrome',
        });
        expect(r.status, 202);
        final id = r.body['id']! as String;

        final stored = (await h.deps.downloads.downloads()).single;
        expect(stored.id, id);
        expect(stored.source, 'chrome');
        final req = stored.snapshot.request;
        expect(req.url.toString(), 'https://example.com/file.zip');
        expect(req.referrer, 'https://example.com/downloads');
        expect(req.userAgent, 'Mozilla/5.0 test');
        expect(req.cookies, 'session=abc; theme=dark');
        expect(req.fileName, 'file.zip');
        // It was handed to the engine, and sorted into its category's folder.
        expect(h.engine.commands.whereType<AddCommand>().single.request.id, id);
        expect(req.saveDir, endsWith('Compressed'));
      },
    );

    test('only url and source are needed', () async {
      final r = await h.post({
        'url': 'https://example.com/a.bin',
        'source': 'firefox',
      });
      expect(r.status, 202);
      expect((await h.deps.downloads.downloads()).single.source, 'firefox');
    });

    test('a missing or wrong token is refused and stores nothing', () async {
      expect((await h.post(_ok, token: null)).status, 401);
      expect((await h.post(_ok, token: 'nope')).status, 401);
      expect((await h.post(_ok, token: '$_token-')).status, 401);
      expect((await h.get('/v1/config', token: 'nope')).status, 401);
      expect(await h.deps.downloads.downloads(), isEmpty);
    });

    test('a request with another Host is rejected', () async {
      for (final host in [
        'evil.example',
        'evil.example:${h.port}',
        '127.0.0.1',
        '127.0.0.1:1',
        '',
      ]) {
        expect(await h.rawStatus(host), 403, reason: 'Host: $host');
      }
      expect(
        (await h.get('/v1/ping', host: 'localhost:${h.port}')).status,
        200,
      );
    });

    test('a link that is not http or https is refused', () async {
      expect(
        (await h.post({'url': 'ftp://example.com/a.zip', 'source': 'chrome'}))
            .status,
        422,
      );
      expect(
        (await h.post({'url': 'file:///etc/passwd', 'source': 'chrome'}))
            .status,
        422,
      );
      expect(
        (await h.post({
          'url': 'https://a.com/x',
          'finalUrl': 'ftp://a.com/x',
          'source': 'chrome',
        })).status,
        422,
      );
      expect(await h.deps.downloads.downloads(), isEmpty);
    });

    test('a body over 256 KB is refused', () async {
      final big = {..._ok, 'cookies': 'a=${'x' * 300000}'};
      expect((await h.post(big)).status, 413);
      expect(await h.deps.downloads.downloads(), isEmpty);
    });

    test('a malformed body is a 400', () async {
      expect((await h.postRaw('not json')).status, 400);
      expect((await h.postRaw('[1,2]')).status, 400);
      expect((await h.post({'source': 'chrome'})).status, 400);
      expect((await h.post({'url': 'https://a.com/x'})).status, 400);
      expect((await h.post({'url': 42, 'source': 'chrome'})).status, 400);
      expect((await h.post({..._ok, 'fileSize': 'big'})).status, 400);
    });

    test('no CORS headers are ever sent', () async {
      for (final r in [
        await h.get('/v1/ping'),
        await h.post(_ok),
        await h.post(_ok, token: 'bad'),
      ]) {
        expect(r.headers.value('access-control-allow-origin'), isNull);
        expect(r.headers.value('access-control-allow-headers'), isNull);
      }
      final pre = await h.send('OPTIONS', '/v1/downloads');
      expect(pre.status, 405);
      expect(pre.headers.value('access-control-allow-origin'), isNull);
    });

    test('unknown routes and wrong methods', () async {
      expect((await h.get('/v1/nothing')).status, 404);
      expect((await h.send('GET', '/v1/downloads', token: _token)).status, 405);
      expect((await h.send('POST', '/v1/ping')).status, 405);
    });

    test('config follows the settings', () async {
      await h.deps.settings.set(Keys.interceptExtensions, ['zip', 'iso']);
      await h.deps.settings.set(Keys.interceptMinBytes, 2048);
      final r = await h.get('/v1/config', token: _token);
      expect(r.status, 200);
      expect(r.body['enabled'], isTrue);
      expect(r.body['interceptExtensions'], ['zip', 'iso']);
      expect(r.body['interceptMinBytes'], 2048);
      expect(r.body['excludedHosts'], isEmpty);

      // A site excluded in Haul's Settings shows up at once.
      await h.deps.siteRules.save(
        const SiteRule(host: 'example.com', neverIntercept: true),
      );
      final again = await h.get('/v1/config', token: _token);
      expect(again.body['excludedHosts'], ['example.com']);

      // And switching browser integration off is passed on.
      await h.deps.settings.set(Keys.browserIntegrationEnabled, false);
      expect(
        (await h.get('/v1/config', token: _token)).body['enabled'],
        isFalse,
      );
    });

    test('the bridge listens on the IPv4 loopback address only', () async {
      expect(h.server.address, InternetAddress.loopbackIPv4);
    });
  });

  group('controller', () {
    test('a taken port is reported and the app carries on', () async {
      final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      await h.deps.settings.set(Keys.bridgePort, blocker.port);
      final c = BridgeController(settings: h.deps.settings, backend: h.intake);
      await c.start();
      expect(c.state.listening, isFalse);
      expect(c.state.error, contains('${blocker.port}'));
      expect(c.state.error, contains('in use'));

      // Choosing another port fixes it without a restart.
      final free = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final freePort = free.port;
      await free.close();
      await h.deps.settings.set(Keys.bridgePort, freePort);
      await _until(() => c.state.listening);
      expect(c.state.port, freePort);
      expect(c.state.error, isNull);
      await c.close();
      await blocker.close();
    });

    test('it restarts on a new port and stops when switched off', () async {
      final free = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final first = free.port;
      await free.close();
      await h.deps.settings.set(Keys.bridgePort, first);
      final c = BridgeController(settings: h.deps.settings, backend: h.intake);
      await c.start();
      expect(c.state.port, first);
      expect(await _ping(first), isTrue);

      final other = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final second = other.port;
      await other.close();
      await h.deps.settings.set(Keys.bridgePort, second);
      await _until(() => c.state.port == second);
      expect(await _ping(second), isTrue);
      expect(await _ping(first), isFalse);

      await h.deps.settings.set(Keys.browserIntegrationEnabled, false);
      await _until(() => !c.state.listening);
      expect(await _ping(second), isFalse);
      expect(c.state.error, isNull);
      await c.close();
    });

    test(
      'a request with the right token tells the app a browser is paired',
      () async {
        var paired = 0;
        h.server.onAuthenticated = () => paired++;
        await h.get('/v1/ping');
        expect(paired, 0);
        await h.get('/v1/config', token: _token);
        expect(paired, 1);
      },
    );
  });

  test('constantTimeEquals', () {
    expect(constantTimeEquals('abc', 'abc'), isTrue);
    expect(constantTimeEquals('abc', 'abd'), isFalse);
    expect(constantTimeEquals('abc', 'ab'), isFalse);
    expect(constantTimeEquals('', ''), isTrue);
  });
}

const _ok = {'url': 'https://example.com/file.zip', 'source': 'chrome'};

Future<void> _until(bool Function() ok) async {
  for (var i = 0; i < 200 && !ok(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(ok(), isTrue);
}

Future<bool> _ping(int port) async {
  final client = HttpClient();
  try {
    final req = await client.get('127.0.0.1', port, '/v1/ping');
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode == 200;
  } on SocketException {
    return false;
  } finally {
    client.close(force: true);
  }
}

/// A bridge on a free port, over a real repository and a fake engine.
class AppHarness {
  AppHarness._(this.deps, this.engine, this.intake, this.server);

  final AppDependencies deps;
  final FakeEngine engine;
  final BrowserIntake intake;
  final BridgeServer server;
  final _client = HttpClient();

  int get port => server.port;

  static Future<AppHarness> create() async {
    final t = await makeTestDeps();
    await t.deps.settings.set(Keys.bridgeToken, _token);
    final intake = BrowserIntake(
      downloads: t.deps.downloads,
      categories: t.deps.categories,
      settings: t.deps.settings,
      siteRules: t.deps.siteRules,
    );
    final server = await BridgeServer.start(
      port: 0,
      token: () => t.deps.settings.get(Keys.bridgeToken),
      backend: intake,
      version: '1.0.0',
    );
    return AppHarness._(t.deps, t.engine, intake, server);
  }

  Future<Reply> get(String path, {String? token, String? host}) =>
      send('GET', path, token: token, host: host);

  Future<Reply> post(Map<String, Object?> body, {String? token = _token}) =>
      postRaw(jsonEncode(body), token: token);

  Future<Reply> postRaw(String body, {String? token = _token}) =>
      send('POST', '/v1/downloads', token: token, body: body);

  Future<Reply> send(
    String method,
    String path, {
    String? token,
    String? host,
    String? body,
  }) async {
    final req = await _client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:$port$path'),
    );
    if (token != null) req.headers.set('X-Bridge-Token', token);
    if (host != null) req.headers.host = host.split(':').first;
    if (host != null && host.contains(':')) {
      req.headers.port = int.parse(host.split(':').last);
    }
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(body));
    }
    final res = await req.close();
    final text = await utf8.decodeStream(res);
    return Reply(
      res.statusCode,
      text.isEmpty ? {} : (jsonDecode(text) as Map).cast<String, Object?>(),
      res.headers,
    );
  }

  /// The status of a ping that says exactly [host] in its Host line (or none
  /// when empty), which an HTTP client library will not send.
  Future<int> rawStatus(String host) async {
    final socket = await Socket.connect('127.0.0.1', port);
    socket.write(
      'GET /v1/ping HTTP/1.0\r\n${host.isEmpty ? '' : 'Host: $host\r\n'}\r\n',
    );
    final text = await utf8.decodeStream(socket);
    await socket.close();
    return int.parse(text.split(' ')[1]);
  }

  Future<void> close() async {
    _client.close(force: true);
    await server.close();
    await deps.dispose();
  }
}
