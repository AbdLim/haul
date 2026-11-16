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
    dir = Directory.systemTemp.createTempSync('ckpt_');
    client = HttpClient()
      ..autoUncompress = false
      ..maxConnectionsPerHost = 16;
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
    dir.deleteSync(recursive: true);
  });

  DownloadTask taskFor({
    Duration? checkpoint = const Duration(milliseconds: 300),
  }) => DownloadTask(
    client: client,
    checkpointInterval: checkpoint,
    snapshot: DownloadSnapshot(
      request: DownloadRequest(
        id: 't',
        url: server.url,
        saveDir: dir.path,
        maxConnections: 4,
      ),
    ),
  );

  test(
    'snapshots are emitted while downloading, and are safe to store',
    () async {
      server = await RangeServer.start(
        size: 12 * mib,
        throttleBytesPerSec: 1 * mib,
      );
      final task = taskFor();
      final checkpoints = <DownloadSnapshot>[];
      final onDisk = <List<int>>[];
      task.events.listen((e) {
        if (e is SnapshotEvent &&
            e.snapshot.status == DownloadStatus.downloading) {
          checkpoints.add(e.snapshot);
          // Read the file the moment the snapshot arrives.
          final part = File(e.snapshot.partPath!);
          if (part.existsSync()) onDisk.add(part.readAsBytesSync());
        }
      });
      final result = await task.run();
      await Future<void>.delayed(Duration.zero);

      expect(
        result.status,
        DownloadStatus.completed,
        reason: '${result.error}',
      );
      expect(checkpoints.length, greaterThan(2));
      // Every stored count is backed by real bytes on disk.
      for (var i = 0; i < onDisk.length; i++) {
        for (final s in checkpoints[i].segments) {
          if (s.downloaded == 0) continue;
          expect(
            onDisk[i].sublist(s.start, s.start + s.downloaded),
            server.bytes(s.start, s.start + s.downloaded - 1),
            reason: 'checkpoint $i, segment ${s.id}',
          );
        }
      }
      // And progress only ever moves forward.
      for (var i = 1; i < checkpoints.length; i++) {
        expect(
          checkpoints[i].downloadedBytes,
          greaterThanOrEqualTo(checkpoints[i - 1].downloadedBytes),
        );
      }
    },
  );

  test('at most one checkpoint per interval', () async {
    server = await RangeServer.start(
      size: 6 * mib,
      throttleBytesPerSec: 1 * mib,
    );
    final task = taskFor(checkpoint: const Duration(milliseconds: 500));
    final times = <DateTime>[];
    task.events.listen((e) {
      if (e is SnapshotEvent &&
          e.snapshot.status == DownloadStatus.downloading) {
        times.add(DateTime.now());
      }
    });
    await task.run();
    // The first "downloading" snapshot is the status change itself.
    for (var i = 2; i < times.length; i++) {
      expect(
        times[i].difference(times[i - 1]),
        greaterThan(const Duration(milliseconds: 350)),
      );
    }
  });

  test('can be switched off', () async {
    server = await RangeServer.start(
      size: 3 * mib,
      throttleBytesPerSec: 2 * mib,
    );
    final task = taskFor(checkpoint: null);
    var downloadingSnapshots = 0;
    task.events.listen((e) {
      if (e is SnapshotEvent &&
          e.snapshot.status == DownloadStatus.downloading) {
        downloadingSnapshots++;
      }
    });
    await task.run();
    expect(downloadingSnapshots, 1);
  });

  test('a checkpoint after a split includes the new segment', () async {
    server = await RangeServer.start(size: 24 * mib);
    server.slowRangeStart = 0;
    server.slowBytesPerSec = 512 * 1024;
    final task = taskFor();
    var maxSegments = 0;
    task.events.listen((e) {
      if (e is SnapshotEvent && e.snapshot.segments.length > maxSegments) {
        maxSegments = e.snapshot.segments.length;
      }
    });
    await task.run();
    expect(maxSegments, greaterThan(4));
  });
}
