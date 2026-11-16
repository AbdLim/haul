import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

import '../test_support/range_server.dart';

const mib = 1024 * 1024;

void main() {
  late Directory dir;
  late RangeServer server;
  late DownloadEngine engine;
  late List<EngineEvent> events;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('login_');
    events = [];
    engine = DownloadEngine(retryDelays: const [Duration.zero]);
    engine.events.listen(events.add);
  });
  tearDown(() async {
    await engine.dispose();
    await server.close();
    dir.deleteSync(recursive: true);
  });

  DownloadRequest req(Uri url, {String id = 'a', int connections = 4}) =>
      DownloadRequest(
        id: id,
        url: url,
        saveDir: '${dir.path}/$id',
        maxConnections: connections,
      );

  DownloadSnapshot? last(String id) {
    for (final e in events.reversed) {
      if (e is SnapshotEvent && e.snapshot.id == id) return e.snapshot;
    }
    return null;
  }

  Future<DownloadSnapshot> settled(String id, {Set<DownloadStatus>? on}) async {
    final stop =
        on ??
        {
          DownloadStatus.completed,
          DownloadStatus.failed,
          DownloadStatus.needsRefresh,
        };
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (true) {
      final s = last(id);
      if (s != null && stop.contains(s.status)) return s;
      if (DateTime.now().isAfter(end)) fail('timed out');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  NetworkConfig loginFor(
    String host, [
    String user = 'bob',
    String pw = 'hunter2',
  ]) => NetworkConfig(siteLogins: {host: SiteLogin(user, pw)});

  test(
    'a protected file downloads when a matching login is supplied',
    () async {
      server = await RangeServer.start(size: 3 * mib);
      server.basicAuthUser = 'bob';
      server.basicAuthPassword = 'hunter2';
      engine.setNetwork(loginFor('127.0.0.1'));
      engine.add(req(server.url));
      final snap = await settled('a');

      expect(snap.status, DownloadStatus.completed, reason: '${snap.error}');
      expect(File('${dir.path}/a/file.bin').readAsBytesSync(), server.allBytes);
      // Every request, probe and segments alike, carried the login.
      expect(server.log.where((e) => e.status == 401), isEmpty);
      expect(
        server.log.every((e) => e.headers.containsKey('authorization')),
        isTrue,
      );
    },
  );

  test('without a login the download fails with authRequired', () async {
    server = await RangeServer.start(size: 500 * 1024);
    server.basicAuthUser = 'bob';
    server.basicAuthPassword = 'hunter2';
    engine.add(req(server.url));
    final snap = await settled('a');
    expect(snap.status, DownloadStatus.failed);
    expect(snap.error!.code, DownloadErrorCode.authRequired);
  });

  test('supplying a login afterwards and retrying completes it', () async {
    server = await RangeServer.start(size: 2 * mib);
    server.basicAuthUser = 'bob';
    server.basicAuthPassword = 'hunter2';
    engine.add(req(server.url));
    expect((await settled('a')).error!.code, DownloadErrorCode.authRequired);

    engine.setNetwork(loginFor('127.0.0.1'));
    engine.resume('a');
    final snap = await settled('a', on: {DownloadStatus.completed});
    expect(snap.status, DownloadStatus.completed);
    expect(File('${dir.path}/a/file.bin').readAsBytesSync(), server.allBytes);
  });

  test('a wrong password is still authRequired', () async {
    server = await RangeServer.start(size: 500 * 1024);
    server.basicAuthUser = 'bob';
    server.basicAuthPassword = 'hunter2';
    engine.setNetwork(loginFor('127.0.0.1', 'bob', 'nope'));
    engine.add(req(server.url));
    expect((await settled('a')).error!.code, DownloadErrorCode.authRequired);
  });

  test('a login for another host is not sent', () async {
    server = await RangeServer.start(size: 500 * 1024);
    server.basicAuthUser = 'bob';
    server.basicAuthPassword = 'hunter2';
    engine.setNetwork(loginFor('example.org'));
    engine.add(req(server.url));
    expect((await settled('a')).error!.code, DownloadErrorCode.authRequired);
    expect(
      server.log.every((e) => !e.headers.containsKey('authorization')),
      isTrue,
    );
  });

  test('single-connection downloads send the login too', () async {
    server = await RangeServer.start(size: 400 * 1024, noRanges: true);
    server.basicAuthUser = 'bob';
    server.basicAuthPassword = 'hunter2';
    engine.setNetwork(loginFor('127.0.0.1'));
    engine.add(req(server.url));
    final snap = await settled('a');
    expect(snap.status, DownloadStatus.completed, reason: '${snap.error}');
    expect(snap.resumable, isFalse);
    expect(server.log.where((e) => e.status == 401), isEmpty);
  });

  test(
    'the login is not leaked to a different host after a redirect',
    () async {
      server = await RangeServer.start(size: 100 * 1024);
      // The file is open to anyone on "localhost" but the redirect target
      // "127.0.0.1" is a different host name; log what it receives.
      final start = server.redirectToHost('/go', '127.0.0.1');
      engine.setNetwork(loginFor('localhost'));
      final viaLocalhost = Uri.parse('http://localhost:${server.port}/go');
      expect(start.path, '/go');
      engine.add(req(viaLocalhost));
      final snap = await settled('a');
      expect(snap.status, DownloadStatus.completed, reason: '${snap.error}');

      final landed = server.log.where((e) => e.path == '/file.bin');
      expect(landed, isNotEmpty);
      for (final e in landed) {
        expect(
          e.headers.containsKey('authorization'),
          isFalse,
          reason: 'the login followed the redirect to another host',
        );
      }
      final first = server.log.firstWhere((e) => e.path == '/go');
      expect(first.headers.containsKey('authorization'), isTrue);
    },
  );

  test('logins survive JSON through the isolate engine', () async {
    server = await RangeServer.start(size: 300 * 1024);
    server.basicAuthUser = 'bob';
    server.basicAuthPassword = 'hunter2';
    final iso = await IsolateEngine.start(retryDelays: const [Duration.zero]);
    final isoEvents = <EngineEvent>[];
    iso.events.listen(isoEvents.add);
    iso.setNetwork(loginFor('127.0.0.1'));
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
  });
}
