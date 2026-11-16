import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

import '../test_support/range_server.dart';

const mib = 1024 * 1024;

void main() {
  late Directory dir;
  late HttpClient client;
  late RangeServer server;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('adapt_');
    client = HttpClient()
      ..autoUncompress = false
      ..maxConnectionsPerHost = 16;
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
    dir.deleteSync(recursive: true);
  });

  DownloadTask taskFor(int connections) => DownloadTask(
    client: client,
    stallTimeout: const Duration(seconds: 5),
    sleep: (_) => Future<void>.delayed(const Duration(milliseconds: 20)),
    snapshot: DownloadSnapshot(
      request: DownloadRequest(
        id: 't',
        url: server.url,
        saveDir: dir.path,
        maxConnections: connections,
      ),
    ),
  );

  test(
    'a server that allows 3 connections still serves a request for 8',
    () async {
      server = await RangeServer.start(
        size: 24 * mib,
        throttleBytesPerSec: 8 * mib,
        maxConnections: 3,
      );
      final result = await taskFor(8).run();

      expect(
        result.status,
        DownloadStatus.completed,
        reason: '${result.error}',
      );
      expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);
      expect(server.peakServed, lessThanOrEqualTo(3));
      expect(
        server.rejected,
        greaterThan(0),
        reason: 'the limit was never hit',
      );
    },
  );

  test('it settles: rejections stop once the limit has adapted', () async {
    server = await RangeServer.start(
      size: 32 * mib,
      throttleBytesPerSec: 4 * mib,
      maxConnections: 3,
    );
    final result = await taskFor(8).run();
    expect(result.status, DownloadStatus.completed, reason: '${result.error}');

    // 8 asked, 3 allowed: the first burst rejects the 5 extras. Afterwards
    // an occasional 503 is possible (a worker reconnects before the server
    // has noticed its previous connection closing), but not a steady stream.
    final log = server.log;
    final firstThird = log.sublist(0, log.length ~/ 3);
    final lastThird = log.sublist(log.length * 2 ~/ 3);
    expect(
      lastThird.where((e) => e.status == 503).length,
      lessThanOrEqualTo(2),
    );
    expect(
      lastThird.where((e) => e.status == 503).length,
      lessThanOrEqualTo(firstThird.where((e) => e.status == 503).length),
    );
    expect(server.rejected, lessThanOrEqualTo(14));
  });

  test('a limit of 1 is never lowered below 1', () async {
    server = await RangeServer.start(
      size: 6 * mib,
      throttleBytesPerSec: 4 * mib,
      maxConnections: 1,
    );
    final result = await taskFor(8).run();
    expect(result.status, DownloadStatus.completed, reason: '${result.error}');
    expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);
    expect(server.peakServed, 1);
  });

  test('429 is treated the same way', () async {
    server = await RangeServer.start(
      size: 16 * mib,
      throttleBytesPerSec: 8 * mib,
      maxConnections: 2,
    );
    server.rejectStatus = 429;
    final result = await taskFor(6).run();
    expect(result.status, DownloadStatus.completed, reason: '${result.error}');
    expect(server.peakServed, lessThanOrEqualTo(2));
    expect(server.log.any((e) => e.status == 429), isTrue);
  });

  test('a lone connection that gets 503 just retries', () async {
    server = await RangeServer.start(size: 1 * mib);
    server.failNextRequests(0);
    // Probe succeeds, then two 503s for the only segment.
    server.failAfterProbeCount = 2;
    final result = await taskFor(1).run();
    expect(result.status, DownloadStatus.completed, reason: '${result.error}');
  });
}
