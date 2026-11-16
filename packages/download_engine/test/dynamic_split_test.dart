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
    dir = Directory.systemTemp.createTempSync('split_');
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
    snapshot: DownloadSnapshot(
      request: DownloadRequest(
        id: 't',
        url: server.url,
        saveDir: dir.path,
        maxConnections: connections,
      ),
    ),
  );

  test('free workers take half of a slow segment', () async {
    const size = 32 * mib;
    server = await RangeServer.start(size: size);
    server.slowRangeStart = 0;
    server.slowBytesPerSec = 512 * 1024; // segment 0 alone would need 16 s

    final task = taskFor(4);
    var maxSegments = 0;
    task.events.listen((e) {
      if (e is ProgressEvent && e.segmentBytes.length > maxSegments) {
        maxSegments = e.segmentBytes.length;
      }
    });
    final watch = Stopwatch()..start();
    final result = await task.run();

    expect(result.status, DownloadStatus.completed, reason: '${result.error}');
    expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);

    // Segment 0 originally covered [0, 8 MiB). New requests must have
    // started inside that range.
    final inside = server.log
        .where((e) => e.rangeStart > 0 && e.rangeStart < 8 * mib)
        .toList();
    expect(
      inside,
      isNotEmpty,
      reason: 'no request began inside the slow segment',
    );

    // The segments still tile the file exactly.
    expect(result.segments.length, greaterThan(4));
    final sorted = [...result.segments]
      ..sort((a, b) => a.start.compareTo(b.start));
    expect(sorted.first.start, 0);
    expect(sorted.last.end, size - 1);
    for (var i = 1; i < sorted.length; i++) {
      expect(sorted[i].start, sorted[i - 1].end + 1);
    }
    expect(maxSegments, greaterThan(4));
    // Without splitting this takes 16 s; with it, far less.
    expect(watch.elapsedMilliseconds, lessThan(10000));
  });

  test('the slow connection stops where its segment now ends', () async {
    const size = 32 * mib;
    server = await RangeServer.start(size: size);
    server.slowRangeStart = 0;
    server.slowBytesPerSec = 1 * mib;
    final result = await taskFor(4).run();
    expect(result.status, DownloadStatus.completed);

    // The first request for segment 0 was cut off, so it sent well under
    // the whole 8 MiB.
    final slow = server.log.firstWhere(
      (e) => e.rangeStart == 0 && e.range != 'bytes=0-0',
    );
    expect(slow.bytesSent, lessThan(8 * mib));
  });

  test('segments with 2 MiB or less left are not split', () async {
    // 4 connections, 4 MiB each; all fast, so nothing is left to steal.
    server = await RangeServer.start(size: 16 * mib);
    final result = await taskFor(4).run();
    expect(result.status, DownloadStatus.completed);
    expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);
  });

  test('a split download can still be paused and resumed', () async {
    const size = 32 * mib;
    server = await RangeServer.start(size: size);
    server.slowRangeStart = 0;
    server.slowBytesPerSec = 1 * mib;
    server.throttleBytesPerSec = 4 * mib;

    final first = taskFor(4);
    final run = first.run();
    first.events.listen((e) {
      if (e is ProgressEvent && e.segmentBytes.length > 4) first.pause();
    });
    final paused = await run;
    expect(paused.status, DownloadStatus.paused);
    expect(paused.segments.length, greaterThan(4));

    server.slowRangeStart = null;
    server.throttleBytesPerSec = null;
    final resumed = await DownloadTask(client: client, snapshot: paused).run();
    expect(resumed.status, DownloadStatus.completed);
    expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);
  });

  test('heavy splitting never miscounts bytes (repeated)', () async {
    // Regression: a victim finishing an in-flight write after its end was
    // lowered used to overcount and fail the final size check.
    server = await RangeServer.start(size: 24 * mib);
    for (var i = 0; i < 6; i++) {
      final sub = Directory('${dir.path}/r$i')..createSync();
      final result = await DownloadTask(
        client: client,
        snapshot: DownloadSnapshot(
          request: DownloadRequest(
            id: 't$i',
            url: server.url,
            saveDir: sub.path,
            maxConnections: 16,
          ),
        ),
      ).run();
      expect(
        result.status,
        DownloadStatus.completed,
        reason: 'run $i: ${result.error}',
      );
      expect(File('${sub.path}/file.bin').readAsBytesSync(), server.allBytes);
    }
  });
}
