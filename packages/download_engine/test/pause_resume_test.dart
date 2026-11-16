import 'dart:convert';
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
    dir = Directory.systemTemp.createTempSync('resume_');
    client = HttpClient()
      ..autoUncompress = false
      ..maxConnectionsPerHost = 16;
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
    dir.deleteSync(recursive: true);
  });

  DownloadTask taskFor(DownloadSnapshot snapshot) => DownloadTask(
    client: client,
    snapshot: snapshot,
    stallTimeout: const Duration(seconds: 5),
  );

  DownloadSnapshot fresh({int connections = 4}) => DownloadSnapshot(
    request: DownloadRequest(
      id: 't',
      url: server.url,
      saveDir: dir.path,
      maxConnections: connections,
    ),
  );

  /// Runs [task] and pauses it once [fraction] of the file has arrived.
  Future<DownloadSnapshot> pauseAt(
    DownloadTask task,
    int total,
    double fraction,
  ) async {
    final run = task.run();
    task.events.listen((e) {
      if (e is ProgressEvent && e.downloadedBytes >= total * fraction) {
        task.pause();
      }
    });
    return run;
  }

  /// Through real JSON text, as the app's database would store it.
  DownloadSnapshot stored(DownloadSnapshot s) => DownloadSnapshot.fromJson(
    jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>,
  );

  test(
    'pause at ~40% then resume from JSON finishes with correct bytes',
    () async {
      const size = 20 * mib;
      server = await RangeServer.start(
        size: size,
        throttleBytesPerSec: 2 * mib,
      );
      final paused = await pauseAt(taskFor(fresh()), size, 0.4);

      expect(paused.status, DownloadStatus.paused);
      expect(paused.downloadedBytes, greaterThanOrEqualTo(size * 0.4 * 0.9));
      expect(paused.downloadedBytes, lessThan(size));
      expect(File('${dir.path}/file.bin.part').existsSync(), isTrue);

      // The stored count must never run ahead of what is on disk.
      final onDisk = File(paused.partPath!).readAsBytesSync();
      for (final s in paused.segments) {
        final written = onDisk.sublist(s.start, s.start + s.downloaded);
        expect(
          written,
          server.bytes(s.start, s.start + s.downloaded - 1),
          reason: 'segment ${s.id} bytes on disk',
        );
      }

      server.throttleBytesPerSec = null;
      server.log.clear();
      final saved = stored(paused);
      final resumed = await taskFor(saved).run();

      expect(resumed.status, DownloadStatus.completed);
      expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);
      expect(File('${dir.path}/file.bin.part').existsSync(), isFalse);

      // Every unfinished segment is picked up exactly where it stopped, and
      // nothing is requested for segments that were already done. A free
      // worker may also split a segment further, which adds requests that
      // start inside an unfinished segment's remaining range.
      final starts = server.log.map((e) => e.rangeStart).toSet();
      final resumePoints = [
        for (final s in saved.segments)
          if (s.downloaded < s.length) s.start + s.downloaded,
      ];
      expect(starts.containsAll(resumePoints), isTrue);
      for (final s in saved.segments.where((s) => s.downloaded >= s.length)) {
        expect(
          starts.where((o) => o >= s.start && o <= s.end),
          isEmpty,
          reason: 'segment ${s.id} was already done',
        );
      }
      for (final extra in starts.difference(resumePoints.toSet())) {
        final owner = saved.segments.firstWhere(
          (s) => extra > s.start + s.downloaded && extra <= s.end,
          orElse: () =>
              throw StateError('request at $extra is in no open segment'),
        );
        expect(owner.downloaded, lessThan(owner.length));
      }

      // Fetched again: the unfinished remainder, plus the little a cut-off
      // connection had already sent.
      final remaining = size - saved.downloadedBytes;
      final fetched = server.log.fold<int>(0, (n, e) => n + e.bytesSent);
      expect(fetched, greaterThanOrEqualTo(remaining));
      expect(fetched, lessThanOrEqualTo(remaining + 4 * mib));
    },
  );

  test('pausing twice, resuming twice', () async {
    const size = 12 * mib;
    server = await RangeServer.start(size: size, throttleBytesPerSec: 2 * mib);
    var snap = await pauseAt(taskFor(fresh()), size, 0.25);
    expect(snap.status, DownloadStatus.paused);
    snap = await pauseAt(taskFor(stored(snap)), size, 0.6);
    expect(snap.status, DownloadStatus.paused);
    server.throttleBytesPerSec = null;
    snap = await taskFor(stored(snap)).run();
    expect(snap.status, DownloadStatus.completed);
    expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);
  });

  test('a single-connection download restarts from zero and says so', () async {
    const size = 4 * mib;
    server = await RangeServer.start(
      size: size,
      noRanges: true,
      throttleBytesPerSec: 2 * mib,
    );
    final paused = await pauseAt(taskFor(fresh()), size, 0.3);

    expect(paused.status, DownloadStatus.paused);
    expect(paused.resumable, isFalse); // the UI warns before pausing these

    server.throttleBytesPerSec = null;
    server.log.clear();
    final resumed = await taskFor(stored(paused)).run();
    expect(resumed.status, DownloadStatus.completed);
    expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);
    expect(server.log.single.range, isNull); // plain GET from byte zero
  });

  test('a missing .part file restarts from zero', () async {
    const size = 8 * mib;
    server = await RangeServer.start(size: size, throttleBytesPerSec: 2 * mib);
    final paused = await pauseAt(taskFor(fresh()), size, 0.4);
    File(paused.partPath!).deleteSync();

    server.throttleBytesPerSec = null;
    final resumed = await taskFor(stored(paused)).run();
    expect(resumed.status, DownloadStatus.completed);
    expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);
  });

  test('a .part file of the wrong length restarts from zero', () async {
    const size = 8 * mib;
    server = await RangeServer.start(size: size, throttleBytesPerSec: 2 * mib);
    final paused = await pauseAt(taskFor(fresh()), size, 0.4);
    File(paused.partPath!).writeAsBytesSync([1, 2, 3]);

    server.throttleBytesPerSec = null;
    final resumed = await taskFor(stored(paused)).run();
    expect(resumed.status, DownloadStatus.completed);
    expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);
  });

  test('pause completes promptly even while connections are stalled', () async {
    const size = 8 * mib;
    server = await RangeServer.start(
      size: size,
      throttleBytesPerSec: 200 * 1024,
    );
    final task = taskFor(fresh());
    final run = task.run();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final watch = Stopwatch()..start();
    await task.pause();
    final snap = await run;
    expect(snap.status, DownloadStatus.paused);
    expect(watch.elapsedMilliseconds, lessThan(2000));
  });

  test('pause before the probe finishes still ends paused', () async {
    server = await RangeServer.start(size: 4 * mib);
    final task = taskFor(fresh());
    final run = task.run();
    final p = task.pause();
    final snap = await run;
    await p;
    expect(snap.status, DownloadStatus.paused);
  });
}
