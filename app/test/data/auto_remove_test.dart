import 'package:download_engine/download_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/dependencies.dart';
import 'package:haul/data/setting_keys.dart';

import '../support/test_deps.dart';

DownloadSnapshot snap(String id, DownloadStatus s) => DownloadSnapshot(
  request: DownloadRequest(
    id: id,
    url: Uri.parse('https://e.com/$id'),
    saveDir: '/d',
  ),
  status: s,
  fileName: '$id.bin',
);

void main() {
  late AppDependencies deps;
  final now = DateTime(2026, 6, 30, 12);

  setUp(() async {
    deps = (await makeTestDeps()).deps;
    final dao = deps.database.downloadsDao;
    await dao.save(
      snap('old', DownloadStatus.completed),
      createdAt: now.subtract(const Duration(days: 20)),
      completedAt: now.subtract(const Duration(days: 8)),
    );
    await dao.save(
      snap('fresh', DownloadStatus.completed),
      createdAt: now.subtract(const Duration(days: 2)),
      completedAt: now.subtract(const Duration(days: 1)),
    );
    await dao.save(snap('paused', DownloadStatus.paused));
  });
  tearDown(() => deps.dispose());

  Future<Set<String>> idsAfter(AutoRemove policy) async {
    await deps.downloads.recover(autoRemove: policy, now: now);
    return {for (final d in await deps.downloads.downloads()) d.id};
  }

  test('never keeps every download', () async {
    expect(await idsAfter(AutoRemove.never), {'old', 'fresh', 'paused'});
  });

  test('after 7 days drops only the finished ones older than that', () async {
    expect(await idsAfter(AutoRemove.afterSevenDays), {'fresh', 'paused'});
  });

  test('on quit drops every finished download, and nothing else', () async {
    expect(await idsAfter(AutoRemove.onQuit), {'paused'});
  });
}
