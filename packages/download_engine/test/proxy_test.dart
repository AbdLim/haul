import 'dart:convert';
import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

import '../test_support/range_server.dart';
import '../test_support/test_proxy.dart';

const mib = 1024 * 1024;

void main() {
  late Directory dir;
  late RangeServer server;
  late TestProxy proxy;
  late DownloadEngine engine;
  late List<EngineEvent> events;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('proxy_');
    proxy = await TestProxy.start();
    events = [];
    engine = DownloadEngine(retryDelays: const [Duration.zero]);
    engine.events.listen(events.add);
  });
  tearDown(() async {
    await engine.dispose();
    await server.close();
    await proxy.close();
    dir.deleteSync(recursive: true);
  });

  DownloadRequest req(Uri url, {String id = 'a'}) => DownloadRequest(
    id: id,
    url: url,
    saveDir: '${dir.path}/$id',
    maxConnections: 4,
  );

  DownloadSnapshot? last(String id) {
    for (final e in events.reversed) {
      if (e is SnapshotEvent && e.snapshot.id == id) return e.snapshot;
    }
    return null;
  }

  Future<DownloadSnapshot> finished(String id) async {
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (true) {
      final s = last(id);
      if (s != null &&
          (s.status == DownloadStatus.completed ||
              s.status == DownloadStatus.failed)) {
        return s;
      }
      if (DateTime.now().isAfter(end)) fail('timed out');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  ProxyConfig proxyConfig({
    String? user,
    String? pass,
    List<String> bypass = const [],
  }) => ProxyConfig(
    host: '127.0.0.1',
    port: proxy.port,
    username: user,
    password: pass,
    bypass: bypass,
  );

  test('with a manual proxy, every request goes through it', () async {
    server = await RangeServer.start(size: 3 * mib);
    engine.setNetwork(NetworkConfig(proxy: proxyConfig()));
    engine.add(req(server.url));
    final snap = await finished('a');

    expect(snap.status, DownloadStatus.completed, reason: '${snap.error}');
    expect(File('${dir.path}/a/file.bin').readAsBytesSync(), server.allBytes);
    // The probe and every segment request appear in the proxy log, and the
    // origin saw exactly as many.
    expect(proxy.log.length, greaterThan(1));
    expect(proxy.log.length, server.log.length);
    expect(proxy.log.every((e) => e.url.port == server.port), isTrue);
    expect(proxy.log.first.range, 'bytes=0-0');
  });

  test('without a proxy, requests go straight to the server', () async {
    server = await RangeServer.start(size: 500 * 1024);
    engine.add(req(server.url));
    expect((await finished('a')).status, DownloadStatus.completed);
    expect(proxy.log, isEmpty);
  });

  test('a host on the bypass list connects directly', () async {
    server = await RangeServer.start(size: 500 * 1024);
    engine.setNetwork(NetworkConfig(proxy: proxyConfig(bypass: ['localhost'])));
    // Same server, reached by a name that is on the bypass list.
    engine.add(req(Uri.parse('http://localhost:${server.port}/file.bin')));
    final snap = await finished('a');
    expect(snap.status, DownloadStatus.completed, reason: '${snap.error}');
    expect(proxy.log, isEmpty);
    expect(server.log, isNotEmpty);

    // And the same engine still proxies a host that is not listed.
    engine.add(req(server.url, id: 'b'));
    expect((await finished('b')).status, DownloadStatus.completed);
    expect(proxy.log, isNotEmpty);
  });

  test('wildcard bypass rules match subdomains and the bare domain', () {
    const p = ProxyConfig(
      host: 'h',
      port: 1,
      bypass: ['*.example.com', 'intranet', ' ', 'LOCALHOST'],
    );
    expect(p.bypasses('a.example.com'), isTrue);
    expect(p.bypasses('example.com'), isTrue);
    expect(p.bypasses('badexample.com'), isFalse);
    expect(p.bypasses('intranet'), isTrue);
    expect(p.bypasses('localhost'), isTrue);
    expect(p.bypasses('other.org'), isFalse);
  });

  test('correct credentials work', () async {
    server = await RangeServer.start(size: 500 * 1024);
    proxy.requireUser = 'alice';
    proxy.requirePassword = 's3cret';
    engine.setNetwork(
      NetworkConfig(
        proxy: proxyConfig(user: 'alice', pass: 's3cret'),
      ),
    );
    engine.add(req(server.url));
    final snap = await finished('a');
    expect(snap.status, DownloadStatus.completed, reason: '${snap.error}');
    expect(File('${dir.path}/a/file.bin').readAsBytesSync(), server.allBytes);
  });

  test('wrong credentials fail with proxyAuth', () async {
    server = await RangeServer.start(size: 500 * 1024);
    proxy.requireUser = 'alice';
    proxy.requirePassword = 's3cret';
    engine.setNetwork(
      NetworkConfig(
        proxy: proxyConfig(user: 'alice', pass: 'wrong'),
      ),
    );
    engine.add(req(server.url));
    final snap = await finished('a');
    expect(snap.status, DownloadStatus.failed);
    expect(snap.error!.code, DownloadErrorCode.proxyAuth);
    expect(server.log, isEmpty);
  });

  test(
    'no credentials against a proxy that wants them fails with proxyAuth',
    () async {
      server = await RangeServer.start(size: 500 * 1024);
      proxy.requireUser = 'alice';
      proxy.requirePassword = 's3cret';
      engine.setNetwork(NetworkConfig(proxy: proxyConfig()));
      engine.add(req(server.url));
      final snap = await finished('a');
      expect(snap.status, DownloadStatus.failed);
      expect(snap.error!.code, DownloadErrorCode.proxyAuth);
    },
  );

  test('passwords with special characters survive', () async {
    server = await RangeServer.start(size: 100 * 1024);
    proxy.requireUser = 'a@b';
    proxy.requirePassword = 'p:w/d@#?';
    engine.setNetwork(
      NetworkConfig(
        proxy: proxyConfig(user: 'a@b', pass: 'p:w/d@#?'),
      ),
    );
    engine.add(req(server.url));
    final snap = await finished('a');
    expect(snap.status, DownloadStatus.completed, reason: '${snap.error}');
  });

  test('removing the proxy sends later requests direct again', () async {
    server = await RangeServer.start(size: 300 * 1024);
    engine.setNetwork(NetworkConfig(proxy: proxyConfig()));
    engine.add(req(server.url));
    await finished('a');
    final through = proxy.log.length;
    expect(through, greaterThan(0));

    engine.setNetwork(const NetworkConfig());
    engine.add(req(server.url, id: 'b'));
    await finished('b');
    expect(proxy.log.length, through);
  });

  test('NetworkConfig and its command survive JSON', () {
    final cfg = NetworkConfig(
      proxy: proxyConfig(user: 'u', pass: 'p', bypass: ['a', '*.b.c']),
      siteLogins: const {'example.com': SiteLogin('me', 'pw')},
      siteLimits: const {'cdn.example.com': 2},
      defaultUserAgent: 'UA/1',
    );
    final cmd = SetNetworkCommand(cfg);
    final back = EngineCommand.fromJson(
      jsonDecode(jsonEncode(cmd.toJson())) as Map<String, Object?>,
    );
    expect(back.toJson(), cmd.toJson());
    expect(back, isA<SetNetworkCommand>());
  });

  test('IsolateEngine carries setNetwork', () async {
    server = await RangeServer.start(size: 300 * 1024);
    final iso = await IsolateEngine.start(retryDelays: const [Duration.zero]);
    final isoEvents = <EngineEvent>[];
    iso.events.listen(isoEvents.add);
    iso.setNetwork(NetworkConfig(proxy: proxyConfig()));
    iso.add(req(server.url, id: 'iso'));
    final end = DateTime.now().add(const Duration(seconds: 15));
    while (!isoEvents.any(
      (e) =>
          e is SnapshotEvent && e.snapshot.status == DownloadStatus.completed,
    )) {
      if (DateTime.now().isAfter(end)) fail('timed out');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await iso.dispose();
    expect(proxy.log, isNotEmpty);
  });
}
