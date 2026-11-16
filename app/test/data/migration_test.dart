// SQL needs single quotes inside its strings.
// ignore_for_file: prefer_single_quotes

import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/data/categories_repository.dart';
import 'package:haul/data/database.dart';
import 'package:haul/data/downloads_repository.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'a version 1 database upgrades to version 2 with its data intact',
    () async {
      final dir = Directory.systemTemp.createTempSync('migrate_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/haul.sqlite';

      // Build a real v1 database from the DDL captured before the change.
      final raw = sql.sqlite3.open(path);
      raw.execute(File('test/data/fixtures/schema_v1.sql').readAsStringSync());
      raw.execute(
        "INSERT INTO downloads (id, url, save_dir, status, created_at) "
        "VALUES ('old', 'https://e.com/a.zip', '/d', 'paused', 1700000000)",
      );
      raw.execute(
        "INSERT INTO segments (download_id, segment_index, start_offset, end_offset, status) "
        "VALUES ('old', 0, 0, 99, 'pending')",
      );
      raw.execute(
        "INSERT INTO settings (key, value) VALUES ('maxConnections', '4')",
      );
      raw.execute('PRAGMA user_version = 1');
      raw.close();

      final db = HaulDatabase.file(File(path));
      addTearDown(db.close);

      final old = await db.downloadsDao.byId('old');
      expect(old, isNotNull);
      expect(old!.snapshot.status, DownloadStatus.paused);
      expect(old.snapshot.segments, hasLength(1));
      expect(old.categoryId, isNull, reason: 'old rows have no category');
      expect((await db.select(db.settings).get()).single.value, '4');

      // The new tables are there and usable.
      final categories = CategoriesRepository(db);
      await categories.ensureBuiltIns('/Users/me/Downloads');
      expect(await categories.all(), hasLength(6));
      expect(await db.select(db.siteRules).get(), isEmpty);
      expect(await db.select(db.siteLogins).get(), isEmpty);

      // And a download can now carry a category.
      final zip = await categories.categoryFor('a.zip');
      await db.downloadsDao.save(old.snapshot, categoryId: zip.id);
      expect((await db.downloadsDao.byId('old'))!.categoryId, zip.id);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 2);
    },
  );

  test('a new download remembers the category that chose its folder', () async {
    final db = HaulDatabase.inMemory();
    addTearDown(db.close);
    final categories = CategoriesRepository(db);
    await categories.ensureBuiltIns('/dl');
    final video = await categories.categoryFor('x.mp4');

    final repo = DownloadsRepository(engine: _Silent(), database: db);
    addTearDown(repo.dispose);
    await repo.add(
      DownloadRequest(
        id: 'a',
        url: Uri.parse('https://e.com/x.mp4'),
        saveDir: video.saveDir,
      ),
      categoryId: video.id,
    );
    final stored = (await db.downloadsDao.byId('a'))!;
    expect(stored.categoryId, video.id);
    expect(stored.snapshot.request.saveDir, '/dl/Video');
  });
}

class _Silent implements EngineApi {
  @override
  Stream<EngineEvent> get events => const Stream.empty();
  @override
  void send(EngineCommand c) {}
  @override
  Future<void> dispose() async {}
}
