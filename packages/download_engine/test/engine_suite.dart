import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

import '../test_support/range_server.dart';

const mib = 1024 * 1024;

void runEngineSuite(
  String label,
  Future<EngineApi> Function({required int concurrent}) create,
) {
  group(label, () {
    late Directory dir;
    late RangeServer server;
    late EngineApi engine;
    late List<EngineEvent> events;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('engine_');
      events = [];
    });
    tearDown(() async {
      await engine.dispose();
      await server.close();
      dir.deleteSync(recursive: true);
    });

    Future<EngineApi> makeEngine({int concurrent = 2}) async {
      engine = await create(concurrent: concurrent);
      engine.events.listen(events.add);
      return engine;
    }

    DownloadRequest req(
      String id, {
      String path = '/file.bin',
      int connections = 2,
    }) => DownloadRequest(
      id: id,
      url: server.urlFor(path),
      saveDir: '${dir.path}/$id',
      maxConnections: connections,
    );

    DownloadStatus? statusOf(String id) {
      for (final e in events.reversed) {
        if (e is SnapshotEvent && e.snapshot.id == id) return e.snapshot.status;
      }
      return null;
    }

    Future<void> until(bool Function() test, {int seconds = 20}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (!test()) {
        if (DateTime.now().isAfter(end)) fail('timed out waiting');
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }
    }

    /// Live byte count from the latest progress event.
    int bytesOf(String id) {
      for (final e in events.reversed) {
        if (e is ProgressEvent && e.id == id) return e.downloadedBytes;
      }
      return 0;
    }

    /// Latest snapshot of every download that still exists, from events only.
    List<DownloadSnapshot> currentSnapshots() {
      final latest = <String, DownloadSnapshot>{};
      for (final e in events) {
        if (e is SnapshotEvent) latest[e.snapshot.id] = e.snapshot;
        if (e is RemovedEvent) latest.remove(e.id);
      }
      return latest.values.toList();
    }

    int concurrentNow() =>
        currentSnapshots().where((s) => s.status.isActive).length;

    test(
      '5 downloads with a limit of 2 never run more than 2 at once',
      () async {
        server = await RangeServer.start(
          size: 2 * mib,
          throttleBytesPerSec: 4 * mib,
        );
        await makeEngine(concurrent: 2);
        var peak = 0;
        engine.events.listen((_) {
          if (concurrentNow() > peak) peak = concurrentNow();
        });
        for (var i = 0; i < 5; i++) {
          engine.add(req('d$i'));
        }
        await until(
          () =>
              [for (var i = 0; i < 5; i++) statusOf('d$i')]
                  .every((s) => s == DownloadStatus.completed),
        );

        expect(peak, 2);
        for (var i = 0; i < 5; i++) {
          expect(
            File('${dir.path}/d$i/file.bin').readAsBytesSync(),
            server.allBytes,
          );
        }
      },
    );

    test('the queue is first in, first out', () async {
      server = await RangeServer.start(
        size: 1 * mib,
        throttleBytesPerSec: 4 * mib,
      );
      await makeEngine(concurrent: 1);
      for (var i = 0; i < 4; i++) {
        engine.add(req('d$i'));
      }
      await until(() => statusOf('d3') == DownloadStatus.completed);
      final startOrder = <String>[];
      for (final e in events) {
        if (e is SnapshotEvent &&
            e.snapshot.status == DownloadStatus.probing &&
            !startOrder.contains(e.snapshot.id)) {
          startOrder.add(e.snapshot.id);
        }
      }
      expect(startOrder, ['d0', 'd1', 'd2', 'd3']);
    });

    test('pausing a running download starts the next queued one', () async {
      server = await RangeServer.start(
        size: 8 * mib,
        throttleBytesPerSec: 2 * mib,
      );
      await makeEngine(concurrent: 1);
      engine.add(req('a'));
      engine.add(req('b'));
      await until(() => statusOf('a') == DownloadStatus.downloading);
      expect(statusOf('b'), DownloadStatus.queued);

      engine.pause('a');
      await until(() => statusOf('a') == DownloadStatus.paused);
      await until(
        () => const {
          DownloadStatus.probing,
          DownloadStatus.downloading,
        }.contains(statusOf('b')),
      );
      expect(statusOf('a'), DownloadStatus.paused);
    });

    test('a paused download can be resumed and finishes', () async {
      server = await RangeServer.start(
        size: 6 * mib,
        throttleBytesPerSec: 3 * mib,
      );
      await makeEngine();
      engine.add(req('a'));
      await until(() => bytesOf('a') > 0);
      engine.pause('a');
      await until(() => statusOf('a') == DownloadStatus.paused);
      server.throttleBytesPerSec = null;
      engine.resume('a');
      await until(() => statusOf('a') == DownloadStatus.completed);
      expect(File('${dir.path}/a/file.bin').readAsBytesSync(), server.allBytes);
    });

    test('a queued download can be paused before it ever starts', () async {
      server = await RangeServer.start(
        size: 8 * mib,
        throttleBytesPerSec: 2 * mib,
      );
      await makeEngine(concurrent: 1);
      engine.add(req('a'));
      engine.add(req('b'));
      engine.pause('b');
      await until(() => statusOf('b') == DownloadStatus.paused);
      engine.cancel('a');
      await until(() => events.any((e) => e is RemovedEvent && e.id == 'a'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(statusOf('b'), DownloadStatus.paused); // never auto-started
    });

    test('cancel deletes the .part file and removes the download', () async {
      server = await RangeServer.start(
        size: 8 * mib,
        throttleBytesPerSec: 2 * mib,
      );
      await makeEngine();
      engine.add(req('a'));
      await until(() => bytesOf('a') > 200 * 1024);
      expect(File('${dir.path}/a/file.bin.part').existsSync(), isTrue);

      engine.cancel('a');
      await until(() => events.any((e) => e is RemovedEvent && e.id == 'a'));
      expect(File('${dir.path}/a/file.bin.part').existsSync(), isFalse);
      expect(currentSnapshots(), isEmpty);
    });

    test(
      'lowering the limit takes effect as running downloads finish',
      () async {
        server = await RangeServer.start(
          size: 4 * mib,
          throttleBytesPerSec: 4 * mib,
        );
        await makeEngine(concurrent: 3);
        for (var i = 0; i < 5; i++) {
          engine.add(req('d$i'));
        }
        await until(() => concurrentNow() == 3);
        engine.setLimits(maxConcurrentDownloads: 1);

        // Running downloads are not interrupted.
        expect(concurrentNow(), 3);
        var peakAfter = 0;
        engine.events.listen((_) {
          if (concurrentNow() > peakAfter) peakAfter = concurrentNow();
        });
        await until(
          () =>
              [for (var i = 0; i < 5; i++) statusOf('d$i')]
                  .every((s) => s == DownloadStatus.completed),
        );
        expect(peakAfter, lessThanOrEqualTo(3));
        // Once the first three were done, the last two ran one at a time.
        final finish = <String, int>{};
        for (var i = 0; i < events.length; i++) {
          final e = events[i];
          if (e is SnapshotEvent &&
              e.snapshot.status == DownloadStatus.completed) {
            finish.putIfAbsent(e.snapshot.id, () => i);
          }
        }
        final start3 = events.indexWhere(
          (e) =>
              e is SnapshotEvent &&
              e.snapshot.id == 'd3' &&
              e.snapshot.status == DownloadStatus.probing,
        );
        final doneBefore = finish.values.where((i) => i < start3).length;
        expect(
          doneBefore,
          3,
          reason: 'd3 must wait until all three have finished',
        );
      },
    );

    test('raising the limit starts queued downloads at once', () async {
      server = await RangeServer.start(
        size: 8 * mib,
        throttleBytesPerSec: 1 * mib,
      );
      await makeEngine(concurrent: 1);
      for (var i = 0; i < 3; i++) {
        engine.add(req('d$i'));
      }
      await until(() => concurrentNow() == 1);
      engine.setLimits(maxConcurrentDownloads: 3);
      await until(() => concurrentNow() == 3);
    });

    test('setLimits changes the shared speed limit while running', () async {
      server = await RangeServer.start(size: 4 * mib);
      await makeEngine();
      engine.setLimits(speedLimitBytesPerSec: 512 * 1024); // 8 s alone
      engine.add(req('a'));
      await until(() => statusOf('a') == DownloadStatus.downloading);
      final watch = Stopwatch()..start();
      engine.setLimits(speedLimitBytesPerSec: 0);
      await until(() => statusOf('a') == DownloadStatus.completed);
      expect(watch.elapsedMilliseconds, lessThan(3000));
    });

    test(
      'setLimits connections applies to downloads that start afterwards',
      () async {
        server = await RangeServer.start(size: 8 * mib);
        await makeEngine();
        engine.setLimits(maxConnections: 1);
        engine.add(req('a', connections: 8));
        await until(() => statusOf('a') == DownloadStatus.completed);
        final done = (events.whereType<SnapshotEvent>().last).snapshot;
        expect(done.segments, hasLength(1));
      },
    );

    test(
      'refreshUrl resumes a needsRefresh download with a new link',
      () async {
        server = await RangeServer.start(size: 8 * mib);
        server.dropAfterBytes = 400 * 1024;
        server.statusAfterBytes = 3 * mib;
        await makeEngine();
        engine.add(req('a', connections: 4));
        await until(() => statusOf('a') == DownloadStatus.needsRefresh);

        server.statusAfterBytes = null;
        server.dropAfterBytes = null;
        engine.refreshUrl(
          'a',
          server.url.replace(queryParameters: {'sig': 'new'}),
        );
        await until(() => statusOf('a') == DownloadStatus.completed);
        expect(
          File('${dir.path}/a/file.bin').readAsBytesSync(),
          server.allBytes,
        );
        expect(server.log.last.path, '/file.bin');
      },
    );

    test('remove forgets a finished download but keeps the file', () async {
      server = await RangeServer.start(size: 100 * 1024);
      await makeEngine();
      engine.add(req('a'));
      await until(() => statusOf('a') == DownloadStatus.completed);
      engine.remove('a');
      await until(() => events.any((e) => e is RemovedEvent));
      expect(currentSnapshots(), isEmpty);
      expect(File('${dir.path}/a/file.bin').existsSync(), isTrue);
    });

    test('a restored snapshot comes back paused and can be resumed', () async {
      server = await RangeServer.start(
        size: 6 * mib,
        throttleBytesPerSec: 3 * mib,
      );
      await makeEngine();
      engine.add(req('a'));
      await until(() => bytesOf('a') > 300 * 1024);
      engine.pause('a');
      await until(() => statusOf('a') == DownloadStatus.paused);
      final saved = currentSnapshots().single;
      await engine.dispose();

      // "Restart the app": a new engine and the stored snapshot.
      server.throttleBytesPerSec = null;
      events.clear();
      await makeEngine();
      final stored = DownloadSnapshot.fromJson(
        jsonDecode(jsonEncode(saved.toJson())) as Map<String, Object?>,
      ).copyWith(status: DownloadStatus.downloading); // as it was when we quit
      engine.add(saved.request, snapshot: stored);
      await until(() => statusOf('a') == DownloadStatus.paused);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(statusOf('a'), DownloadStatus.paused); // nothing starts by itself

      engine.resume('a');
      await until(() => statusOf('a') == DownloadStatus.completed);
      expect(File('${dir.path}/a/file.bin').readAsBytesSync(), server.allBytes);
    });

    test('every event survives a JSON round trip', () async {
      server = await RangeServer.start(
        size: 2 * mib,
        throttleBytesPerSec: 4 * mib,
      );
      await makeEngine();
      engine.add(req('a'));
      await until(() => statusOf('a') == DownloadStatus.completed);
      // Progress events depend on timing and are covered in models_test.
      expect(events.whereType<SnapshotEvent>(), isNotEmpty);
      for (final e in events) {
        final back = EngineEvent.fromJson(
          jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>,
        );
        expect(back.toJson(), e.toJson());
      }
    });

    test('duplicate ids are ignored and unknown ids do nothing', () async {
      server = await RangeServer.start(size: 100 * 1024);
      await makeEngine();
      engine.add(req('a'));
      engine.add(req('a'));
      engine.pause('nope');
      engine.resume('nope');
      engine.cancel('nope');
      engine.remove('nope');
      await until(() => statusOf('a') == DownloadStatus.completed);
      expect(currentSnapshots(), hasLength(1));
    });
  });
}
