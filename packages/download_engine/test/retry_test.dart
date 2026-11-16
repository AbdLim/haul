import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

import '../test_support/range_server.dart';

const mib = 1024 * 1024;

void main() {
  late Directory dir;
  late HttpClient client;
  late RangeServer server;
  late List<Duration> sleeps;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('retry_');
    client = HttpClient()
      ..autoUncompress = false
      ..maxConnectionsPerHost = 16;
    sleeps = [];
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
    dir.deleteSync(recursive: true);
  });

  DownloadTask taskFor({
    int connections = 4,
    Duration stall = const Duration(seconds: 5),
  }) => DownloadTask(
    client: client,
    stallTimeout: stall,
    // Record the schedule but don't actually wait.
    sleep: (d) async => sleeps.add(d),
    snapshot: DownloadSnapshot(
      request: DownloadRequest(
        id: 't',
        url: server.url,
        saveDir: dir.path,
        maxConnections: connections,
      ),
    ),
  );

  test('a dropped connection resumes from the right offset', () async {
    const size = 600 * 1024;
    server = await RangeServer.start(size: size);
    server.dropAfterBytes = 100 * 1024; // every response is cut short
    final result = await taskFor(connections: 1).run();

    expect(result.status, DownloadStatus.completed, reason: '${result.error}');
    expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);

    // After the probe, each request picks up where the last one stopped.
    final starts = server.log.skip(1).map((e) => e.rangeStart).toList();
    expect(starts, [
      0,
      100 * 1024,
      200 * 1024,
      300 * 1024,
      400 * 1024,
      500 * 1024,
    ]);
  });

  test(
    'a server that stops sending trips the stall timeout, then recovers',
    () async {
      const size = 1 * mib;
      server = await RangeServer.start(size: size);
      server.stallResponses = 1;
      server.stallAfterBytes = 200 * 1024;
      final watch = Stopwatch()..start();
      final result = await taskFor(
        connections: 1,
        stall: const Duration(milliseconds: 400),
      ).run();

      expect(
        result.status,
        DownloadStatus.completed,
        reason: '${result.error}',
      );
      expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);
      expect(watch.elapsedMilliseconds, lessThan(5000));
      // Probe, the stalled request, then the retry from where it stalled.
      expect(server.log.length, 3);
      expect(
        server.log.last.rangeStart,
        greaterThanOrEqualTo(200 * 1024 - 64 * 1024),
      );
      expect(sleeps, hasLength(1));
    },
  );

  test('8 failures in a row end in failed and keep the .part file', () async {
    server = await RangeServer.start(size: 600 * 1024);
    server.failAfterProbe = 503;
    final result = await taskFor(connections: 1).run();

    expect(result.status, DownloadStatus.failed);
    expect(result.error!.message, contains('gave up after 8'));
    expect(File('${dir.path}/file.bin.part').existsSync(), isTrue);
    // The probe plus exactly eight attempts at the segment.
    expect(server.log.length, 1 + 8);
  });

  test('backoff is 1, 2, 4, 8, 16, then 30 seconds', () async {
    server = await RangeServer.start(size: 600 * 1024);
    server.failAfterProbe = 503;
    await taskFor(connections: 1).run();
    expect(sleeps.map((d) => d.inSeconds), [1, 2, 4, 8, 16, 30, 30]);
  });

  test('the failure count resets whenever bytes arrive', () async {
    // 20 drops in a row is far above 8, but each one made progress.
    const size = 2 * mib;
    server = await RangeServer.start(size: size);
    server.dropAfterBytes = 100 * 1024;
    final result = await taskFor(connections: 1).run();
    expect(result.status, DownloadStatus.completed, reason: '${result.error}');
    expect(server.log.length, greaterThan(20));
    // Every wait was the first step of the schedule.
    expect(sleeps.every((d) => d == const Duration(seconds: 1)), isTrue);
  });

  test('temporary errors on the probe are retried too', () async {
    server = await RangeServer.start(size: 100 * 1024);
    server.failNextRequests(3, 503);
    final result = await taskFor().run();
    expect(result.status, DownloadStatus.completed);
    expect(sleeps.map((d) => d.inSeconds), [1, 2, 4]);
  });

  test('permanent errors are not retried', () async {
    server = await RangeServer.start(size: 600 * 1024);
    server.failAfterProbe = 403;
    final result = await taskFor(connections: 1).run();
    expect(result.status, DownloadStatus.failed);
    expect(result.error!.code, DownloadErrorCode.forbidden);
    expect(sleeps, isEmpty);
    expect(server.log.length, 2);
  });

  test('a single-connection download retries from zero', () async {
    server = await RangeServer.start(size: 400 * 1024, noRanges: true);
    server.dropAfterBytes = 300 * 1024;
    var calls = 0;
    // Only the first response is cut; later ones are complete.
    server.dropAfterBytes = 100 * 1024;
    final task = DownloadTask(
      client: client,
      sleep: (d) async {
        calls++;
        server.dropAfterBytes = null;
      },
      snapshot: DownloadSnapshot(
        request: DownloadRequest(id: 't', url: server.url, saveDir: dir.path),
      ),
    );
    final result = await task.run();
    expect(result.status, DownloadStatus.completed, reason: '${result.error}');
    expect(calls, 1);
    expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);
  });

  test('pausing cuts a backoff wait short', () async {
    server = await RangeServer.start(size: 600 * 1024);
    server.failAfterProbe = 503;
    final task = DownloadTask(
      client: client,
      // A real, long wait.
      retryDelays: const [Duration(seconds: 30)],
      snapshot: DownloadSnapshot(
        request: DownloadRequest(
          id: 't',
          url: server.url,
          saveDir: dir.path,
          maxConnections: 1,
        ),
      ),
    );
    final run = task.run();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final watch = Stopwatch()..start();
    await task.pause();
    final snap = await run;
    expect(snap.status, DownloadStatus.paused);
    expect(watch.elapsedMilliseconds, lessThan(2000));
  });
}
