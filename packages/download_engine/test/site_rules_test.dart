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
    dir = Directory.systemTemp.createTempSync('rules_');
    events = [];
    engine = DownloadEngine(retryDelays: const [Duration.zero]);
    engine.events.listen(events.add);
  });
  tearDown(() async {
    await engine.dispose();
    await server.close();
    dir.deleteSync(recursive: true);
  });

  DownloadRequest req({int connections = 8, String id = 'a', String? ua}) =>
      DownloadRequest(
        id: id,
        url: server.url,
        saveDir: '${dir.path}/$id',
        maxConnections: connections,
        userAgent: ua,
      );

  Future<DownloadSnapshot> completed(String id) async {
    final end = DateTime.now().add(const Duration(seconds: 25));
    while (true) {
      for (final e in events.reversed) {
        if (e is SnapshotEvent &&
            e.snapshot.id == id &&
            (e.snapshot.status == DownloadStatus.completed ||
                e.snapshot.status == DownloadStatus.failed)) {
          return e.snapshot;
        }
      }
      if (DateTime.now().isAfter(end)) fail('timed out');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  group('per-site connection limits', () {
    test('a rule of 2 caps a request for 8', () async {
      server = await RangeServer.start(
        size: 24 * mib,
        throttleBytesPerSec: 6 * mib,
      );
      engine.setNetwork(const NetworkConfig(siteLimits: {'127.0.0.1': 2}));
      engine.add(req());
      final snap = await completed('a');

      expect(snap.status, DownloadStatus.completed, reason: '${snap.error}');
      expect(File('${dir.path}/a/file.bin').readAsBytesSync(), server.allBytes);
      expect(server.peakConcurrent, lessThanOrEqualTo(2));
      expect(server.peakServed, 2, reason: 'it should still use both');
      expect(server.rejected, 0);
    });

    test('the effective count is the smaller of the two settings', () async {
      server = await RangeServer.start(
        size: 12 * mib,
        throttleBytesPerSec: 6 * mib,
      );
      engine.setNetwork(const NetworkConfig(siteLimits: {'127.0.0.1': 4}));
      engine.add(req(connections: 1));
      expect((await completed('a')).status, DownloadStatus.completed);
      expect(server.peakConcurrent, 1);
    });

    test('a host without a rule uses the download\'s own setting', () async {
      server = await RangeServer.start(
        size: 24 * mib,
        throttleBytesPerSec: 6 * mib,
      );
      engine.setNetwork(const NetworkConfig(siteLimits: {'other.example': 1}));
      engine.add(req(connections: 4));
      expect((await completed('a')).status, DownloadStatus.completed);
      expect(server.peakConcurrent, greaterThan(2));
      expect(server.peakConcurrent, lessThanOrEqualTo(4));
    });

    test('the segment plan respects the cap too', () async {
      server = await RangeServer.start(size: 16 * mib);
      engine.setNetwork(const NetworkConfig(siteLimits: {'127.0.0.1': 3}));
      engine.add(req());
      await completed('a');
      final planned = events
          .whereType<SnapshotEvent>()
          .map((e) => e.snapshot)
          .firstWhere((s) => s.segments.isNotEmpty);
      expect(planned.segments.length, lessThanOrEqualTo(3));
    });

    test('a rule below 1 is ignored', () async {
      server = await RangeServer.start(
        size: 12 * mib,
        throttleBytesPerSec: 6 * mib,
      );
      engine.setNetwork(const NetworkConfig(siteLimits: {'127.0.0.1': 0}));
      engine.add(req(connections: 3));
      expect((await completed('a')).status, DownloadStatus.completed);
      expect(server.peakConcurrent, 3);
    });

    test('a download resumed under a new rule obeys it', () async {
      server = await RangeServer.start(
        size: 24 * mib,
        throttleBytesPerSec: 3 * mib,
      );
      engine.add(req(connections: 6));
      while (!events.any(
        (e) => e is ProgressEvent && e.downloadedBytes > 2 * mib,
      )) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      engine.pause('a');
      while (!events.any(
        (e) => e is SnapshotEvent && e.snapshot.status == DownloadStatus.paused,
      )) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      // Old connections drain on the server a moment after the pause.
      var spins = 0;
      while (server.activeNow > 0 && spins++ < 100) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      // A handler whose client aborted mid-throttle can linger on the test
      // server; count only what the resumed download adds on top of it.
      final stale = server.activeNow;
      server.throttleBytesPerSec = 8 * mib;
      server.log.clear();
      server.peakConcurrent = stale;
      engine.setNetwork(const NetworkConfig(siteLimits: {'127.0.0.1': 2}));
      engine.resume('a');
      final snap = await completed('a');
      expect(snap.status, DownloadStatus.completed, reason: '${snap.error}');
      expect(server.peakConcurrent - stale, lessThanOrEqualTo(2));
    });
  });

  group('default user agent', () {
    test('is used when the download has none of its own', () async {
      server = await RangeServer.start(size: 3 * mib);
      engine.setNetwork(const NetworkConfig(defaultUserAgent: 'HaulTest/9.9'));
      engine.add(req());
      await completed('a');
      expect(server.log, isNotEmpty);
      for (final e in server.log) {
        expect(e.headers['user-agent'], 'HaulTest/9.9');
      }
    });

    test('a browser-supplied user agent wins', () async {
      server = await RangeServer.start(size: 500 * 1024);
      engine.setNetwork(const NetworkConfig(defaultUserAgent: 'HaulTest/9.9'));
      engine.add(req(ua: 'Firefox/200'));
      await completed('a');
      expect(
        server.log.every((e) => e.headers['user-agent'] == 'Firefox/200'),
        isTrue,
      );
    });

    test(
      'falls back to a desktop browser string when nothing is set',
      () async {
        server = await RangeServer.start(size: 100 * 1024);
        engine.add(req());
        await completed('a');
        expect(server.log.first.headers['user-agent'], contains('Mozilla/5.0'));
      },
    );

    test('applies to single-connection downloads', () async {
      server = await RangeServer.start(size: 200 * 1024, noRanges: true);
      engine.setNetwork(const NetworkConfig(defaultUserAgent: 'HaulTest/9.9'));
      engine.add(req());
      await completed('a');
      expect(
        server.log.every((e) => e.headers['user-agent'] == 'HaulTest/9.9'),
        isTrue,
      );
    });
  });

  test('both rules travel through IsolateEngine', () async {
    server = await RangeServer.start(
      size: 12 * mib,
      throttleBytesPerSec: 6 * mib,
    );
    final iso = await IsolateEngine.start(retryDelays: const [Duration.zero]);
    final isoEvents = <EngineEvent>[];
    iso.events.listen(isoEvents.add);
    iso.setNetwork(
      const NetworkConfig(
        siteLimits: {'127.0.0.1': 2},
        defaultUserAgent: 'IsoUA/1',
      ),
    );
    iso.add(req(id: 'iso'));
    final end = DateTime.now().add(const Duration(seconds: 25));
    while (!isoEvents.any(
      (e) =>
          e is SnapshotEvent && e.snapshot.status == DownloadStatus.completed,
    )) {
      if (DateTime.now().isAfter(end)) fail('timed out');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await iso.dispose();
    expect(server.peakConcurrent, lessThanOrEqualTo(2));
    expect(
      server.log.every((e) => e.headers['user-agent'] == 'IsoUA/1'),
      isTrue,
    );
  });
}
