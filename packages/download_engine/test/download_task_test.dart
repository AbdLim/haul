import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

import '../test_support/range_server.dart';

void main() {
  late Directory dir;
  late HttpClient client;
  late RangeServer server;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('task_');
    client = HttpClient()
      ..autoUncompress = false
      ..maxConnectionsPerHost = 16;
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
    dir.deleteSync(recursive: true);
  });

  DownloadTask newTask({
    int connections = 8,
    String? fileName,
    Uri? url,
    Duration speedWindow = const Duration(seconds: 5),
  }) => DownloadTask(
    client: client,
    speedWindow: speedWindow,
    stallTimeout: const Duration(seconds: 5),
    snapshot: DownloadSnapshot(
      request: DownloadRequest(
        id: 't1',
        url: url ?? server.url,
        saveDir: dir.path,
        fileName: fileName,
        maxConnections: connections,
      ),
    ),
  );

  int segmentRequests() =>
      server.log.where((e) => e.range != null && e.range != 'bytes=0-0').length;

  test('50 MiB over 8 connections matches the source byte for byte', () async {
    const size = 50 * 1024 * 1024;
    server = await RangeServer.start(size: size);
    final result = await newTask().run();

    expect(result.status, DownloadStatus.completed, reason: '${result.error}');
    expect(result.error, isNull);
    expect(result.fileName, 'file.bin');
    expect(result.totalBytes, size);
    // Eight planned segments; free workers may split them further.
    expect(result.segments.length, greaterThanOrEqualTo(8));
    expect(result.downloadedBytes, size);

    final out = File('${dir.path}/file.bin');
    expect(out.lengthSync(), size);
    expect(out.readAsBytesSync(), server.allBytes);
    expect(File('${dir.path}/file.bin.part').existsSync(), isFalse);

    // The first eight requests are the planned segments, at exact offsets.
    final planned = planSegments(size, 8).map((s) => s.start).toSet();
    final started = server.log.map((e) => e.rangeStart).toSet();
    expect(started.containsAll(planned), isTrue);
    expect(segmentRequests(), greaterThanOrEqualTo(8));
  });

  test('a server without ranges downloads over one connection', () async {
    server = await RangeServer.start(size: 3 * 1024 * 1024, noRanges: true);
    final result = await newTask().run();

    expect(result.status, DownloadStatus.completed);
    expect(result.resumable, isFalse);
    expect(result.supportsRanges, isFalse);
    expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);
    // Probe, then one plain GET with no Range header.
    expect(server.log, hasLength(2));
    expect(server.log.last.range, isNull);
  });

  test('a server that does not report a total size still works', () async {
    server = await RangeServer.start(size: 2 * 1024 * 1024);
    server.unknownTotal = true;
    final result = await newTask().run();

    expect(result.status, DownloadStatus.completed);
    expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);
  });

  test('a small file uses one segment', () async {
    server = await RangeServer.start(size: 500 * 1024);
    final result = await newTask().run();
    expect(result.segments, hasLength(1));
    expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);
  });

  test('an empty file completes', () async {
    server = await RangeServer.start(size: 0);
    final result = await newTask().run();
    expect(result.status, DownloadStatus.completed);
    expect(File('${dir.path}/file.bin').lengthSync(), 0);
  });

  test('the .part file is renamed only at the end', () async {
    server = await RangeServer.start(
      size: 2 * 1024 * 1024,
      throttleBytesPerSec: 4 * 1024 * 1024,
    );
    final task = newTask(connections: 2);
    final future = task.run();
    var sawPart = false;
    while (task.snapshot.status != DownloadStatus.completed) {
      if (File('${dir.path}/file.bin.part').existsSync() &&
          !File('${dir.path}/file.bin').existsSync()) {
        sawPart = true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await future;
    expect(sawPart, isTrue);
  });

  test('the caller can choose the file name', () async {
    server = await RangeServer.start(size: 1000);
    final result = await newTask(fileName: 'mine.dat').run();
    expect(result.fileName, 'mine.dat');
    expect(File('${dir.path}/mine.dat').existsSync(), isTrue);
  });

  test('Content-Disposition names the file', () async {
    server = await RangeServer.start(
      size: 1000,
      contentDisposition: 'attachment; filename="from-header.zip"',
    );
    final result = await newTask().run();
    expect(result.fileName, 'from-header.zip');
  });

  test('never overwrites an existing file', () async {
    server = await RangeServer.start(size: 1000);
    File('${dir.path}/file.bin').writeAsStringSync('keep me');
    final result = await newTask().run();
    expect(result.fileName, 'file (1).bin');
    expect(File('${dir.path}/file.bin').readAsStringSync(), 'keep me');
  });

  test('a missing file fails with a typed error', () async {
    server = await RangeServer.start(size: 10);
    final result = await newTask(url: server.urlFor('/nope')).run();
    expect(result.status, DownloadStatus.failed);
    expect(result.error!.code, DownloadErrorCode.notFound);
  });

  test('a permanent failure mid-download keeps the .part file', () async {
    server = await RangeServer.start(size: 4 * 1024 * 1024);
    // Every segment request after the probe fails with a hard 403.
    server.failAfterProbe = 403;
    final result = await newTask(connections: 2).run();
    expect(result.status, DownloadStatus.failed);
    expect(result.error!.code, DownloadErrorCode.forbidden);
    expect(File('${dir.path}/file.bin.part').existsSync(), isTrue);
    expect(File('${dir.path}/file.bin').existsSync(), isFalse);
  });

  test('emits status snapshots in order', () async {
    server = await RangeServer.start(size: 1000);
    final task = newTask();
    final seen = <DownloadStatus>[];
    task.events.listen((e) {
      if (e is SnapshotEvent) seen.add(e.snapshot.status);
    });
    await task.run();
    await Future<void>.delayed(Duration.zero);
    expect(seen, [
      DownloadStatus.probing,
      DownloadStatus.downloading,
      DownloadStatus.completed,
    ]);
  });

  test(
    'falls back to one connection when ranges are ignored mid-download',
    () async {
      server = await RangeServer.start(size: 4 * 1024 * 1024);
      server.ignoreRangeAfterProbe = true;
      final result = await newTask(connections: 4).run();

      expect(
        result.status,
        DownloadStatus.completed,
        reason: '${result.error}',
      );
      expect(result.resumable, isFalse);
      expect(result.segments, hasLength(1));
      expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);
    },
  );

  test('reported speed settles near the combined throttle', () async {
    // 4 connections at 1 MiB/s each. A 2 s window keeps the test short; the
    // 5 s default behaves the same once it has filled.
    const mib = 1024 * 1024;
    server = await RangeServer.start(size: 16 * mib, throttleBytesPerSec: mib);
    final task = newTask(
      connections: 4,
      speedWindow: const Duration(seconds: 2),
    );
    final progress = <(DateTime, ProgressEvent)>[];
    task.events.listen((e) {
      if (e is ProgressEvent) progress.add((DateTime.now(), e));
    });
    final result = await task.run();
    expect(result.status, DownloadStatus.completed);

    // Skip the first 2.5 s while the window fills; the rest of the run
    // should sit between 3.5 and 4.5 MiB/s.
    final settled = progress.skip(10).map((p) => p.$2.bytesPerSecond).toList();
    expect(settled, isNotEmpty);
    for (final v in settled) {
      expect(v, inInclusiveRange(3.5 * mib, 4.5 * mib));
    }
    expect(progress.last.$2.segmentBytes, hasLength(4));
    expect(progress.last.$2.totalBytes, 16 * mib);
    expect(progress.any((p) => p.$2.eta != null), isTrue);
  });

  test('never more than 4 progress events in any second', () async {
    server = await RangeServer.start(
      size: 6 * 1024 * 1024,
      throttleBytesPerSec: 3 * 1024 * 1024,
    );
    final task = newTask(connections: 2);
    final times = <DateTime>[];
    task.events.listen((e) {
      if (e is ProgressEvent) times.add(DateTime.now());
    });
    await task.run();
    expect(times.length, greaterThan(2));
    for (var i = 0; i + 4 < times.length; i++) {
      // Five events must span more than one second.
      expect(
        times[i + 4].difference(times[i]),
        greaterThan(const Duration(milliseconds: 900)),
      );
    }
  });

  test('uses its connections in parallel', () async {
    // 4 connections at 1 MiB/s each: 8 MiB takes about 2 s in parallel and
    // about 8 s over one connection.
    const mib = 1024 * 1024;
    server = await RangeServer.start(size: 8 * mib, throttleBytesPerSec: mib);
    final watch = Stopwatch()..start();
    final result = await newTask(connections: 4).run();
    expect(result.status, DownloadStatus.completed, reason: '${result.error}');
    expect(server.peakServed, 4);
    expect(watch.elapsedMilliseconds, lessThan(5000));
  });

  test(
    'progress events carry the live segments, in step with their bytes',
    () async {
      const mib = 1024 * 1024;
      server = await RangeServer.start(size: 6 * mib, throttleBytesPerSec: mib);
      final task = newTask(connections: 3);
      final events = <ProgressEvent>[];
      task.events.listen((e) {
        if (e is ProgressEvent) events.add(e);
      });
      await task.run();
      expect(events, isNotEmpty);
      for (final e in events) {
        expect(e.segments.length, e.segmentBytes.length);
        for (var i = 0; i < e.segments.length; i++) {
          expect(e.segments[i].downloaded, e.segmentBytes[i]);
        }
      }
      // The ranges tile the file.
      final first = [...events.first.segments]
        ..sort((a, b) => a.start.compareTo(b.start));
      expect(first.first.start, 0);
      expect(first.last.end, 6 * mib - 1);
    },
  );
}
