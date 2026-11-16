import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

import '../test_support/range_server.dart';

const mib = 1024 * 1024;

void main() {
  late Directory dir;
  late RangeServer server;
  setUp(() => dir = Directory.systemTemp.createTempSync('isohost_'));
  tearDown(() async {
    await server.close();
    dir.deleteSync(recursive: true);
  });

  DownloadRequest req(String id) => DownloadRequest(
    id: id,
    url: server.url,
    saveDir: '${dir.path}/$id',
    maxConnections: 4,
  );

  test(
    'dispose is safe to call twice and later commands are ignored',
    () async {
      server = await RangeServer.start(size: 1000);
      final engine = await IsolateEngine.start();
      await engine.dispose();
      await engine.dispose();
      engine.add(req('late')); // must not throw
      expect(server.log, isEmpty);
    },
  );

  test('dispose stops running downloads and keeps their .part files', () async {
    server = await RangeServer.start(
      size: 8 * mib,
      throttleBytesPerSec: 1 * mib,
    );
    final engine = await IsolateEngine.start();
    final events = <EngineEvent>[];
    engine.events.listen(events.add);
    engine.add(req('a'));
    while (!events.any(
      (e) => e is ProgressEvent && e.downloadedBytes > 100 * 1024,
    )) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await engine.dispose();
    expect(File('${dir.path}/a/file.bin.part').existsSync(), isTrue);
    expect(File('${dir.path}/a/file.bin').existsSync(), isFalse);
    final last = events.whereType<SnapshotEvent>().last.snapshot;
    expect(last.status, DownloadStatus.paused);
  });

  test(
    'the calling isolate stays responsive during a heavy download',
    () async {
      server = await RangeServer.start(size: 24 * mib);
      final engine = await IsolateEngine.start();
      var done = false;
      engine.events.listen((e) {
        if (e is SnapshotEvent &&
            e.snapshot.status == DownloadStatus.completed) {
          done = true;
        }
      });
      engine.add(req('a'));

      // A 10 ms ticker on this isolate should never be starved by the engine.
      var worst = Duration.zero;
      var last = DateTime.now();
      while (!done) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final now = DateTime.now();
        final gap = now.difference(last) - const Duration(milliseconds: 10);
        if (gap > worst) worst = gap;
        last = now;
      }
      await engine.dispose();
      expect(File('${dir.path}/a/file.bin').lengthSync(), 24 * mib);
      expect(worst, lessThan(const Duration(milliseconds: 250)));
    },
  );

  test('commands and events really cross as JSON maps', () async {
    server = await RangeServer.start(size: 300 * 1024);
    final engine = await IsolateEngine.start();
    final events = <EngineEvent>[];
    engine.events.listen(events.add);
    engine.send(AddCommand(req('a')));
    while (!events.any(
      (e) =>
          e is SnapshotEvent && e.snapshot.status == DownloadStatus.completed,
    )) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await engine.dispose();
    expect(events.first, isA<SnapshotEvent>());
    expect((events.first as SnapshotEvent).snapshot.request.url, server.url);
  });

  test(
    'kill stops everything at once, and dispose afterwards returns',
    () async {
      server = await RangeServer.start(
        size: 8 * mib,
        throttleBytesPerSec: 1 * mib,
      );
      final engine = await IsolateEngine.start();
      final events = <EngineEvent>[];
      engine.events.listen(events.add);
      engine.add(req('a'));
      while (!events.any(
        (e) => e is ProgressEvent && e.downloadedBytes > 100 * 1024,
      )) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      engine.kill();
      await engine.dispose().timeout(const Duration(seconds: 2));

      // A crash leaves no goodbye: no paused snapshot, and the .part stays.
      final last = events.whereType<SnapshotEvent>().last.snapshot;
      expect(last.status, isNot(DownloadStatus.paused));
      expect(File('${dir.path}/a/file.bin.part').existsSync(), isTrue);
    },
  );
}
