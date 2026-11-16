import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/data/database.dart';
import 'package:haul/data/downloads_dao.dart';

DownloadSnapshot sample(
  String id, {
  DownloadStatus status = DownloadStatus.downloading,
  List<Segment>? segments,
}) => DownloadSnapshot(
  request: DownloadRequest(
    id: id,
    url: Uri.parse('https://example.com/$id.zip?sig=1'),
    saveDir: '/tmp/dl',
    fileName: 'wanted.zip',
    referrer: 'https://example.com/page',
    userAgent: 'UA/1',
    cookies: 'a=b',
    maxConnections: 4,
  ),
  status: status,
  finalUrl: Uri.parse('https://cdn.example.com/$id.zip'),
  fileName: '$id.zip',
  totalBytes: 1000,
  supportsRanges: true,
  etag: '"e"',
  lastModified: 'Wed, 01 Jan 2025 00:00:00 GMT',
  contentType: 'application/zip',
  segments:
      segments ??
      const [
        Segment(
          id: 0,
          start: 0,
          end: 499,
          downloaded: 100,
          status: SegmentStatus.active,
        ),
        Segment(
          id: 1,
          start: 500,
          end: 999,
          downloaded: 500,
          status: SegmentStatus.done,
        ),
      ],
);

void main() {
  // Tests open a second database on purpose (reopening a file).
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late HaulDatabase db;
  setUp(() => db = HaulDatabase.inMemory());
  tearDown(() => db.close());

  test('insert and read back a download with its segments', () async {
    final snap = sample('a');
    await db.downloadsDao.save(snap, source: 'chrome');

    final stored = await db.downloadsDao.byId('a');
    expect(stored, isNotNull);
    expect(stored!.snapshot.toJson(), snap.toJson());
    expect(stored.source, 'chrome');
    expect(stored.snapshot.downloadedBytes, 600);
  });

  test('request headers survive the round trip', () async {
    await db.downloadsDao.save(sample('a'));
    final r = (await db.downloadsDao.byId('a'))!.snapshot.request;
    expect(r.referrer, 'https://example.com/page');
    expect(r.userAgent, 'UA/1');
    expect(r.cookies, 'a=b');
    expect(r.fileName, 'wanted.zip');
    expect(r.maxConnections, 4);
  });

  test('update replaces the row and its segments', () async {
    await db.downloadsDao.save(sample('a'));
    final moved = sample(
      'a',
      segments: const [
        Segment(
          id: 0,
          start: 0,
          end: 249,
          downloaded: 250,
          status: SegmentStatus.done,
        ),
        Segment(id: 1, start: 250, end: 499, downloaded: 10),
        Segment(
          id: 2,
          start: 500,
          end: 999,
          downloaded: 500,
          status: SegmentStatus.done,
        ),
      ],
    );
    await db.downloadsDao.save(moved);

    final stored = (await db.downloadsDao.byId('a'))!.snapshot;
    expect(stored.segments, hasLength(3));
    expect(stored.downloadedBytes, 760);
    expect((await db.downloadsDao.all()), hasLength(1));
    final rows = await db.select(db.segments).get();
    expect(rows, hasLength(3));
  });

  test('createdAt is kept on update and completedAt is set once', () async {
    final first = DateTime.utc(2026, 2, 1);
    await db.downloadsDao.save(sample('a'), createdAt: first);
    await db.downloadsDao.save(sample('a'), createdAt: DateTime.utc(2030));
    expect(
      (await db.downloadsDao.byId('a'))!.createdAt.isAtSameMomentAs(first),
      isTrue,
    );
    expect((await db.downloadsDao.byId('a'))!.completedAt, isNull);

    await db.downloadsDao.save(sample('a', status: DownloadStatus.completed));
    final done = (await db.downloadsDao.byId('a'))!.completedAt;
    expect(done, isNotNull);
    await db.downloadsDao.save(sample('a', status: DownloadStatus.completed));
    expect((await db.downloadsDao.byId('a'))!.completedAt, done);
  });

  test('errors are stored and restored', () async {
    final failed = sample('a', status: DownloadStatus.failed).copyWith(
      error: const DownloadError(DownloadErrorCode.forbidden, 'No access'),
    );
    await db.downloadsDao.save(failed);
    final e = (await db.downloadsDao.byId('a'))!.snapshot.error!;
    expect(e.code, DownloadErrorCode.forbidden);
    expect(e.message, 'No access');
  });

  test('a download with nothing probed yet is storable', () async {
    final fresh = DownloadSnapshot(
      request: DownloadRequest(
        id: 'n',
        url: Uri.parse('https://example.com/f'),
        saveDir: '/d',
      ),
    );
    await db.downloadsDao.save(fresh);
    final s = (await db.downloadsDao.byId('n'))!.snapshot;
    expect(s.fileName, isNull);
    expect(s.totalBytes, isNull);
    expect(s.segments, isEmpty);
    expect(s.status, DownloadStatus.queued);
  });

  test('deleting a download deletes its segments', () async {
    await db.downloadsDao.save(sample('a'));
    await db.downloadsDao.save(sample('b'));
    await db.downloadsDao.deleteById('a');

    expect(await db.downloadsDao.byId('a'), isNull);
    final rows = await db.select(db.segments).get();
    expect(rows.every((r) => r.downloadId == 'b'), isTrue);
    expect(rows, hasLength(2));
  });

  test('all() is oldest first', () async {
    await db.downloadsDao.save(
      sample('b'),
      createdAt: DateTime.utc(2026, 2, 2),
    );
    await db.downloadsDao.save(
      sample('a'),
      createdAt: DateTime.utc(2026, 2, 1),
    );
    expect([for (final s in await db.downloadsDao.all()) s.id], ['a', 'b']);
  });

  test('watchAll emits on changes, including segment-only ones', () async {
    final seen = <List<StoredDownload>>[];
    final sub = db.downloadsDao.watchAll().listen(seen.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen.last, isEmpty);

    await db.downloadsDao.save(sample('a'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen.last.single.snapshot.downloadedBytes, 600);

    // Change only a segment row.
    await (db.update(db.segments)..where((t) => t.segmentIndex.equals(0)))
        .write(const SegmentsCompanion(downloadedBytes: Value(400)));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen.last.single.snapshot.downloadedBytes, 900);
    await sub.cancel();
  });

  test('foreign keys are enforced', () async {
    await expectLater(
      db
          .into(db.segments)
          .insert(
            SegmentsCompanion.insert(
              downloadId: 'nope',
              segmentIndex: 0,
              startOffset: 0,
              endOffset: 1,
              status: 'pending',
            ),
          ),
      throwsA(anything),
    );
  });

  test('data survives closing and reopening a file database', () async {
    final dir = Directory.systemTemp.createTempSync('haul_db_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/sub/haul.sqlite');

    final first = HaulDatabase.file(file);
    await first.downloadsDao.save(sample('a'));
    await first.close();

    final second = HaulDatabase.file(file);
    final stored = await second.downloadsDao.byId('a');
    expect(stored!.snapshot.segments, hasLength(2));
    expect(second.schemaVersion, first.schemaVersion);
    await second.close();
  });
}
