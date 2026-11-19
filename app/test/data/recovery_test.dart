import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/data/database.dart';
import 'package:haul/data/downloads_dao.dart';
import 'package:haul/data/downloads_repository.dart';

import '../../../packages/download_engine/test_support/range_server.dart';

const mib = 1024 * 1024;

/// Windows keeps a killed isolate's files locked until the process exits, so
/// the crashed engine's `.part` files can be neither deleted nor opened again
/// by the recovering one. An in-process crash cannot be simulated there; the
/// crash tests run where the operating system lets go of the files.
final _skipCrash = Platform.isWindows
    ? 'a killed isolate keeps its files locked on Windows'
    : null;

Future<void> settle([int ms = 40]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late Directory dir;
  late RangeServer server;
  late HaulDatabase db;

  setUp(() {
    driftIgnore();
    dir = Directory.systemTemp.createTempSync('recover_');
    db = HaulDatabase.file(File('${dir.path}/haul.sqlite'));
  });
  tearDown(() async {
    await server.close();
    await db.close();
    dir.deleteSync(recursive: true);
  });

  DownloadRequest req(String id, {int connections = 4}) => DownloadRequest(
    id: id,
    url: server.url,
    saveDir: '${dir.path}/$id',
    maxConnections: connections,
  );

  Future<StoredDownload> waitFor(
    String id,
    bool Function(StoredDownload) test, {
    int seconds = 30,
  }) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (true) {
      final d = await db.downloadsDao.byId(id);
      if (d != null && test(d)) return d;
      if (DateTime.now().isAfter(end)) {
        fail('timed out waiting for $id; now ${d?.snapshot.status}');
      }
      await settle(30);
    }
  }

  /// Runs a download until the database holds mid-download progress, then
  /// "crashes": the engine isolate is killed with no goodbye.
  Future<DownloadsRepository> crashMidDownload(
    List<String> ids, {
    int connections = 4,
  }) async {
    final engine = await IsolateEngine.start(maxConcurrentDownloads: 3);
    final repo = DownloadsRepository(
      engine: engine,
      database: db,
      saveInterval: const Duration(milliseconds: 200),
    );
    for (final id in ids) {
      await repo.add(req(id, connections: connections));
    }
    for (final id in ids) {
      await waitFor(
        id,
        (d) =>
            d.snapshot.status == DownloadStatus.downloading &&
            d.snapshot.downloadedBytes > 0,
      );
    }
    engine.kill();
    await repo.dispose(); // only flushes what was already received
    return repo;
  }

  test('a crashed download is left as downloading in the database', () async {
    server = await RangeServer.start(
      size: 12 * mib,
      throttleBytesPerSec: 1 * mib,
    );
    await crashMidDownload(['a']);
    final d = (await db.downloadsDao.byId('a'))!;
    expect(d.snapshot.status, DownloadStatus.downloading);
    expect(d.snapshot.downloadedBytes, greaterThan(0));
    expect(d.snapshot.downloadedBytes, lessThan(12 * mib));
  }, skip: _skipCrash);

  test(
    'after a crash, a new repository resumes it and the bytes are right',
    () async {
      server = await RangeServer.start(
        size: 12 * mib,
        throttleBytesPerSec: 1 * mib,
      );
      await crashMidDownload(['a']);

      server.throttleBytesPerSec = null;
      final repo = DownloadsRepository(
        engine: await IsolateEngine.start(),
        database: db,
        saveInterval: const Duration(milliseconds: 200),
      );
      addTearDown(repo.dispose);
      await repo.recover();

      final done = await waitFor(
        'a',
        (d) => d.snapshot.status == DownloadStatus.completed,
      );
      expect(done.snapshot.downloadedBytes, 12 * mib);
      expect(File('${dir.path}/a/file.bin').readAsBytesSync(), server.allBytes);
      expect(File('${dir.path}/a/file.bin.part').existsSync(), isFalse);
    },
    skip: _skipCrash,
  );

  test(
    'with resume on launch off, interrupted downloads come back paused',
    () async {
      server = await RangeServer.start(
        size: 12 * mib,
        throttleBytesPerSec: 1 * mib,
      );
      await crashMidDownload(['a']);

      server.throttleBytesPerSec = null;
      server.log.clear();
      final repo = DownloadsRepository(
        engine: await IsolateEngine.start(),
        database: db,
        saveInterval: const Duration(milliseconds: 200),
      );
      addTearDown(repo.dispose);
      await repo.recover(resumeOnLaunch: false);

      final paused = await waitFor(
        'a',
        (d) => d.snapshot.status == DownloadStatus.paused,
      );
      expect(paused.snapshot.downloadedBytes, greaterThan(0));
      await settle(400);
      expect(server.log, isEmpty, reason: 'nothing should have been requested');

      // Resuming by hand finishes it.
      repo.resume('a');
      await waitFor('a', (d) => d.snapshot.status == DownloadStatus.completed);
      expect(File('${dir.path}/a/file.bin').readAsBytesSync(), server.allBytes);
    },
    skip: _skipCrash,
  );

  test(
    'a download whose .part file is missing starts over from zero',
    () async {
      server = await RangeServer.start(
        size: 8 * mib,
        throttleBytesPerSec: 1 * mib,
      );
      await crashMidDownload(['a']);
      File('${dir.path}/a/file.bin.part').deleteSync();

      server.throttleBytesPerSec = null;
      final repo = DownloadsRepository(
        engine: await IsolateEngine.start(),
        database: db,
        saveInterval: const Duration(milliseconds: 200),
      );
      addTearDown(repo.dispose);
      await repo.recover();

      final done = await waitFor(
        'a',
        (d) => d.snapshot.status == DownloadStatus.completed,
      );
      expect(done.snapshot.downloadedBytes, 8 * mib);
      expect(File('${dir.path}/a/file.bin').readAsBytesSync(), server.allBytes);
    },
    skip: _skipCrash,
  );

  test('finished, failed and paused downloads are not touched', () async {
    server = await RangeServer.start(size: 1000);
    DownloadSnapshot row(
      String id,
      DownloadStatus status, {
      DownloadError? error,
    }) => DownloadSnapshot(
      request: DownloadRequest(
        id: id,
        url: server.url,
        saveDir: '${dir.path}/$id',
      ),
      status: status,
      fileName: 'file.bin',
      totalBytes: 1000,
      error: error,
    );
    await db.downloadsDao.save(row('done', DownloadStatus.completed));
    await db.downloadsDao.save(
      row(
        'bad',
        DownloadStatus.failed,
        error: const DownloadError(DownloadErrorCode.notFound, 'gone'),
      ),
    );
    await db.downloadsDao.save(row('hold', DownloadStatus.paused));

    final repo = DownloadsRepository(
      engine: await IsolateEngine.start(),
      database: db,
      saveInterval: const Duration(milliseconds: 100),
    );
    addTearDown(repo.dispose);
    await repo.recover();
    await settle(500);

    expect(server.log, isEmpty);
    final byId = {
      for (final d in await db.downloadsDao.all()) d.id: d.snapshot.status,
    };
    expect(byId, {
      'done': DownloadStatus.completed,
      'bad': DownloadStatus.failed,
      'hold': DownloadStatus.paused,
    });
    expect(
      (await db.downloadsDao.byId('bad'))!.snapshot.error!.code,
      DownloadErrorCode.notFound,
    );
  });

  test(
    'several interrupted downloads resume in the order they were added',
    () async {
      server = await RangeServer.start(
        size: 6 * mib,
        throttleBytesPerSec: 1 * mib,
      );
      await crashMidDownload(['a', 'b', 'c']);

      server.throttleBytesPerSec = null;
      final engine = await IsolateEngine.start(maxConcurrentDownloads: 1);
      final repo = DownloadsRepository(
        engine: engine,
        database: db,
        saveInterval: const Duration(milliseconds: 100),
      );
      addTearDown(repo.dispose);
      final started = <String>[];
      engine.events.listen((e) {
        if (e is SnapshotEvent &&
            e.snapshot.status == DownloadStatus.probing &&
            !started.contains(e.snapshot.id)) {
          started.add(e.snapshot.id);
        }
      });
      await repo.recover();
      for (final id in ['a', 'b', 'c']) {
        await waitFor(id, (d) => d.snapshot.status == DownloadStatus.completed);
      }
      expect(started, ['a', 'b', 'c']);
    },
    skip: _skipCrash,
  );

  test('an empty database recovers to nothing', () async {
    server = await RangeServer.start(size: 10);
    final repo = DownloadsRepository(
      engine: await IsolateEngine.start(),
      database: db,
    );
    addTearDown(repo.dispose);
    await repo.recover();
    expect(await db.downloadsDao.all(), isEmpty);
  });
}

void driftIgnore() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
}
