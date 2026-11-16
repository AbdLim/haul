import 'dart:async';
import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/data/database.dart';
import 'package:haul/data/downloads_dao.dart';
import 'package:haul/data/downloads_repository.dart';

import '../../../packages/download_engine/test_support/range_server.dart';

const mib = 1024 * 1024;

class FakeEngine implements EngineApi {
  final controller = StreamController<EngineEvent>.broadcast();
  final commands = <EngineCommand>[];

  @override
  Stream<EngineEvent> get events => controller.stream;

  @override
  void send(EngineCommand command) => commands.add(command);

  @override
  Future<void> dispose() async {}
}

DownloadSnapshot snap(
  String id, {
  DownloadStatus status = DownloadStatus.downloading,
  int downloaded = 0,
}) => DownloadSnapshot(
  request: DownloadRequest(
    id: id,
    url: Uri.parse('https://example.com/$id'),
    saveDir: '/tmp',
  ),
  status: status,
  fileName: '$id.bin',
  totalBytes: 1000,
  supportsRanges: true,
  segments: [
    Segment(
      id: 0,
      start: 0,
      end: 999,
      downloaded: downloaded,
      status: SegmentStatus.active,
    ),
  ],
);

Future<void> settle([int ms = 60]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('with a fake engine', () {
    late HaulDatabase db;
    late FakeEngine engine;
    late DownloadsRepository repo;

    setUp(() {
      db = HaulDatabase.inMemory();
      engine = FakeEngine();
      repo = DownloadsRepository(
        engine: engine,
        database: db,
        saveInterval: const Duration(milliseconds: 300),
      );
    });
    tearDown(() async {
      await repo.dispose();
      await db.close();
    });

    test('the default save interval is one second', () {
      final r = DownloadsRepository(engine: FakeEngine(), database: db);
      expect(r.saveInterval, const Duration(seconds: 1));
    });

    test('a status change is written at once', () async {
      engine.controller.add(
        SnapshotEvent(snap('a', status: DownloadStatus.probing)),
      );
      await settle();
      expect(
        (await db.downloadsDao.byId('a'))!.snapshot.status,
        DownloadStatus.probing,
      );

      engine.controller.add(SnapshotEvent(snap('a')));
      await settle();
      expect(
        (await db.downloadsDao.byId('a'))!.snapshot.status,
        DownloadStatus.downloading,
      );
      expect(repo.saveCount, 2);
    });

    test('writes for one download stay at least one interval apart', () async {
      engine.controller.add(SnapshotEvent(snap('a')));
      await settle();
      final before = repo.saveCount;

      // 50 checkpoints in about 1 second, all with the same status.
      for (var i = 1; i <= 50; i++) {
        engine.controller.add(SnapshotEvent(snap('a', downloaded: i * 10)));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await settle(400);

      final writes = repo.saveCount - before;
      // About 1 s at one write per 300 ms: a handful, never fifty.
      expect(writes, lessThanOrEqualTo(5));
      expect(writes, greaterThanOrEqualTo(2));
      // The newest value still made it to the database.
      final stored = (await db.downloadsDao.byId('a'))!.snapshot;
      expect(stored.downloadedBytes, 500);
    });

    test('the last waiting snapshot is written on dispose', () async {
      engine.controller.add(SnapshotEvent(snap('a')));
      await settle();
      engine.controller.add(SnapshotEvent(snap('a', downloaded: 777)));
      await settle(20); // inside the interval: still waiting
      expect((await db.downloadsDao.byId('a'))!.snapshot.downloadedBytes, 0);

      await repo.dispose();
      expect((await db.downloadsDao.byId('a'))!.snapshot.downloadedBytes, 777);
    });

    test('downloads do not throttle each other', () async {
      engine.controller.add(SnapshotEvent(snap('a')));
      engine.controller.add(SnapshotEvent(snap('b')));
      await settle();
      expect(await db.downloadsDao.all(), hasLength(2));
    });

    test('a removed download is deleted from the database', () async {
      engine.controller.add(SnapshotEvent(snap('a')));
      await settle();
      expect(await db.downloadsDao.byId('a'), isNotNull);
      engine.controller.add(const RemovedEvent('a'));
      await settle();
      expect(await db.downloadsDao.byId('a'), isNull);
    });

    test(
      'add stores the row first, with its source, then tells the engine',
      () async {
        await repo.add(
          DownloadRequest(
            id: 'n',
            url: Uri.parse('https://e.com/f'),
            saveDir: '/d',
          ),
          source: 'chrome',
        );
        final stored = (await db.downloadsDao.byId('n'))!;
        expect(stored.source, 'chrome');
        expect(stored.snapshot.status, DownloadStatus.queued);
        expect(engine.commands.single, isA<AddCommand>());

        // The source survives later snapshots from the engine.
        engine.controller.add(SnapshotEvent(snap('n')));
        await settle();
        expect((await db.downloadsDao.byId('n'))!.source, 'chrome');
      },
    );

    test('progress and file-changed events are passed on', () async {
      final progress = <ProgressEvent>[];
      final changed = <String>[];
      repo.progress.listen(progress.add);
      repo.fileChanged.listen(changed.add);
      engine.controller.add(
        const ProgressEvent(
          id: 'a',
          downloadedBytes: 5,
          bytesPerSecond: 1,
          segmentBytes: [5],
        ),
      );
      engine.controller.add(const FileChangedEvent('a'));
      await settle();
      expect(progress.single.downloadedBytes, 5);
      expect(changed, ['a']);
      // Progress is live data and is not written to the database.
      expect(repo.saveCount, 0);
    });

    test('commands are forwarded to the engine', () async {
      repo.pause('a');
      repo.resume('a');
      repo.cancel('a');
      repo.remove('a');
      repo.setLimits(maxConcurrentDownloads: 2, speedLimitBytesPerSec: 5);
      expect(engine.commands.map((c) => c.runtimeType), [
        PauseCommand,
        ResumeCommand,
        CancelCommand,
        RemoveCommand,
        SetLimitsCommand,
      ]);
    });

    test('watchDownloads reflects what was saved', () async {
      final seen = <int>[];
      final sub = repo.watchDownloads().listen((l) => seen.add(l.length));
      engine.controller.add(SnapshotEvent(snap('a')));
      await settle();
      engine.controller.add(SnapshotEvent(snap('b')));
      await settle();
      await sub.cancel();
      expect(seen.last, 2);
    });
  });

  group('with the real engine in an isolate', () {
    late Directory dir;
    late RangeServer server;
    late HaulDatabase db;
    late DownloadsRepository repo;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('repo_');
      db = HaulDatabase.inMemory();
    });
    tearDown(() async {
      await repo.dispose();
      await db.close();
      await server.close();
      dir.deleteSync(recursive: true);
    });

    Future<StoredDownload> waitFor(
      String id,
      bool Function(StoredDownload) test,
    ) async {
      final end = DateTime.now().add(const Duration(seconds: 30));
      while (true) {
        final d = await db.downloadsDao.byId(id);
        if (d != null && test(d)) return d;
        if (DateTime.now().isAfter(end)) fail('timed out waiting for $id');
        await settle(30);
      }
    }

    test('a download runs and the database ends up matching it', () async {
      server = await RangeServer.start(
        size: 12 * mib,
        throttleBytesPerSec:
            1 * mib, // 4 connections: about 3 s, so a checkpoint lands mid-way
      );
      repo = DownloadsRepository(
        engine: await IsolateEngine.start(),
        database: db,
        saveInterval: const Duration(milliseconds: 300),
      );
      await repo.add(
        DownloadRequest(
          id: 'a',
          url: server.url,
          saveDir: '${dir.path}/a',
          maxConnections: 4,
        ),
      );

      // Mid-download rows have real segment offsets.
      final mid = await waitFor(
        'a',
        (d) =>
            d.snapshot.status == DownloadStatus.downloading &&
            d.snapshot.downloadedBytes > 0,
      );
      expect(mid.snapshot.segments, isNotEmpty);
      expect(mid.snapshot.downloadedBytes, lessThan(12 * mib));

      final done = await waitFor(
        'a',
        (d) => d.snapshot.status == DownloadStatus.completed,
      );
      expect(done.snapshot.fileName, 'file.bin');
      expect(done.snapshot.downloadedBytes, 12 * mib);
      expect(done.snapshot.totalBytes, 12 * mib);
      expect(done.completedAt, isNotNull);
      expect(File('${dir.path}/a/file.bin').lengthSync(), 12 * mib);
      final rows = await db.select(db.segments).get();
      expect(rows.fold<int>(0, (n, r) => n + r.downloadedBytes), 12 * mib);
    });

    test(
      'database writes stay within one per second per active download',
      () async {
        server = await RangeServer.start(
          size: 16 * mib,
          throttleBytesPerSec: 2 * mib,
        );
        repo = DownloadsRepository(
          engine: await IsolateEngine.start(),
          database: db,
        );
        await repo.add(
          DownloadRequest(
            id: 'a',
            url: server.url,
            saveDir: '${dir.path}/a',
            maxConnections: 4,
          ),
        );
        final watch = Stopwatch()..start();
        await waitFor(
          'a',
          (d) => d.snapshot.status == DownloadStatus.completed,
        );
        watch.stop();

        // A few status changes, plus at most one write per second in between.
        final seconds = watch.elapsedMilliseconds / 1000;
        expect(repo.saveCount, lessThanOrEqualTo(seconds.ceil() + 6));
        expect(repo.saveCount, greaterThan(2));
      },
    );

    test('cancel removes the row and the partial file', () async {
      server = await RangeServer.start(
        size: 16 * mib,
        throttleBytesPerSec: 1 * mib,
      );
      repo = DownloadsRepository(
        engine: await IsolateEngine.start(),
        database: db,
      );
      await repo.add(
        DownloadRequest(id: 'a', url: server.url, saveDir: '${dir.path}/a'),
      );
      await waitFor('a', (d) => d.snapshot.downloadedBytes > 0);
      repo.cancel('a');
      final end = DateTime.now().add(const Duration(seconds: 15));
      while (await db.downloadsDao.byId('a') != null) {
        if (DateTime.now().isAfter(end)) fail('row never removed');
        await settle(30);
      }
      expect(File('${dir.path}/a/file.bin.part').existsSync(), isFalse);
    });
  });
}
