import 'package:download_engine/download_engine.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/data/categories_repository.dart';
import 'package:haul/data/database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late HaulDatabase db;
  late CategoriesRepository repo;
  const downloads = '/Users/me/Downloads';

  setUp(() async {
    db = HaulDatabase.inMemory();
    repo = CategoriesRepository(db);
    await repo.ensureBuiltIns(downloads);
  });
  tearDown(() => db.close());

  test(
    'the six built-in categories exist, in order, with their folders',
    () async {
      final all = await repo.all();
      expect(all.map((c) => c.name), [
        'Compressed',
        'Documents',
        'Music',
        'Video',
        'Programs',
        'Other',
      ]);
      expect(all.every((c) => c.builtIn), isTrue);
      expect(all.first.saveDir, '$downloads/Compressed');
      expect(all[3].saveDir, '$downloads/Video');
      expect(
        all.last.saveDir,
        downloads,
        reason: 'Other uses Downloads itself',
      );
    },
  );

  test('the default extensions are the standard lists', () async {
    final byName = {for (final c in await repo.all()) c.name: c.extensions};
    expect(byName['Compressed'], ['zip', 'rar', '7z', 'tar', 'gz']);
    expect(byName['Documents'], [
      'pdf', 'epub', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', //
    ]);
    expect(byName['Music'], ['mp3', 'flac', 'wav', 'aac', 'm4a']);
    expect(byName['Video'], ['mp4', 'mkv', 'mov', 'avi', 'webm']);
    expect(byName['Programs'], ['dmg', 'pkg', 'iso', 'exe', 'msi', 'apk']);
    expect(byName['Other'], isEmpty);
  });

  test(
    'a .zip lands in Compressed and a .mp4 in Video, with the right folders',
    () async {
      final zip = await repo.categoryFor('archive.zip');
      expect(zip.name, 'Compressed');
      expect(await repo.saveDirFor('archive.zip'), '$downloads/Compressed');

      final video = await repo.categoryFor('movie.mp4');
      expect(video.name, 'Video');
      expect(await repo.saveDirFor('movie.mp4'), '$downloads/Video');
    },
  );

  test('matching ignores case and uses the last extension', () async {
    expect((await repo.categoryFor('REPORT.PDF')).name, 'Documents');
    expect((await repo.categoryFor('backup.tar.gz')).name, 'Compressed');
    expect((await repo.categoryFor('Installer.DMG')).name, 'Programs');
  });

  test('anything else goes to Other', () async {
    expect((await repo.categoryFor('notes.xyz')).name, 'Other');
    expect((await repo.categoryFor('README')).name, 'Other');
    expect((await repo.categoryFor('.hidden')).name, 'Other');
    expect((await repo.categoryFor('trailing.')).name, 'Other');
    expect(await repo.saveDirFor('notes.xyz'), downloads);
  });

  test('ensureBuiltIns is safe to repeat and keeps edits', () async {
    final video = (await repo.all()).firstWhere((c) => c.name == 'Video');
    await repo.setSaveDir(video.id, '/Volumes/Big/Movies');
    await repo.ensureBuiltIns('/somewhere/else');
    final all = await repo.all();
    expect(all, hasLength(6));
    expect(
      all.firstWhere((c) => c.name == 'Video').saveDir,
      '/Volumes/Big/Movies',
    );
  });

  test('editing a category folder changes only new downloads', () async {
    // An existing download was given its folder when it was added.
    final before = await repo.saveDirFor('old.mp4');
    final existing = DownloadRequest(
      id: 'old',
      url: Uri.parse('https://e.com/old.mp4'),
      saveDir: before,
    );

    final video = await repo.categoryFor('x.mp4');
    await repo.setSaveDir(video.id, '/Volumes/Big/Movies');

    expect(existing.saveDir, '$downloads/Video', reason: 'already added');
    expect(await repo.saveDirFor('new.mp4'), '/Volumes/Big/Movies');
  });

  test('editing extensions moves files between categories', () async {
    final all = await repo.all();
    final docs = all.firstWhere((c) => c.name == 'Documents');
    final programs = all.firstWhere((c) => c.name == 'Programs');
    await repo.setExtensions(docs.id, [...docs.extensions, '.DMG', ' txt ']);
    await repo.setExtensions(
      programs.id,
      programs.extensions.where((e) => e != 'dmg').toList(),
    );
    expect((await repo.categoryFor('a.dmg')).name, 'Documents');
    expect((await repo.categoryFor('a.txt')).name, 'Documents');
    final stored = (await repo.all()).firstWhere((c) => c.name == 'Documents');
    expect(stored.extensions, containsAll(['dmg', 'txt']));
  });

  test('resetBuiltIn restores the default extensions and folder', () async {
    final music = (await repo.all()).firstWhere((c) => c.name == 'Music');
    await repo.setSaveDir(music.id, '/tmp/x');
    await repo.setExtensions(music.id, ['ogg']);
    await repo.resetBuiltIn(music.id, downloads);
    final back = (await repo.all()).firstWhere((c) => c.name == 'Music');
    expect(back.saveDir, '$downloads/Music');
    expect(back.extensions, ['mp3', 'flac', 'wav', 'aac', 'm4a']);
  });

  test('watchAll follows changes', () async {
    final seen = <String>[];
    final sub = repo.watchAll().listen(
      (l) => seen.add(l.firstWhere((c) => c.name == 'Music').saveDir),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final music = (await repo.all()).firstWhere((c) => c.name == 'Music');
    await repo.setSaveDir(music.id, '/tmp/m');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(seen.first, '$downloads/Music');
    expect(seen.last, '/tmp/m');
  });

  test('extensionOf', () {
    expect(CategoriesRepository.extensionOf('a.B'), 'b');
    expect(CategoriesRepository.extensionOf('a.b.c'), 'c');
    expect(CategoriesRepository.extensionOf('none'), isNull);
    expect(CategoriesRepository.extensionOf('.dot'), isNull);
  });
}
