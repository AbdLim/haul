import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/platform_names.dart';
import 'package:haul/data/downloads_dao.dart';
import 'package:haul/features/downloads/row_actions.dart';
import 'package:haul/services/system/macos_platform_services.dart';

StoredDownload dl(
  String id,
  DownloadStatus status, {
  bool resumable = true,
  int done = 0,
}) => StoredDownload(
  snapshot: DownloadSnapshot(
    request: DownloadRequest(
      id: id,
      url: Uri.parse('https://e.com/$id'),
      saveDir: '/d',
    ),
    status: status,
    fileName: '$id.bin',
    totalBytes: 100,
    resumable: resumable,
    segments: [Segment(id: 0, start: 0, end: 99, downloaded: done)],
  ),
  source: 'manual',
  createdAt: DateTime.utc(2026),
);

List<RowAction> actionsFor(DownloadStatus s) => availableActions([dl('a', s)]);

void main() {
  group('which actions apply to one download', () {
    test('a running download can be paused, not resumed', () {
      expect(actionsFor(DownloadStatus.downloading), [
        RowAction.pause,
        RowAction.showInFinder,
        RowAction.copyUrl,
        RowAction.cancel,
      ]);
    });

    test('connecting and queued are treated as running', () {
      for (final s in [DownloadStatus.probing, DownloadStatus.queued]) {
        expect(actionsFor(s), contains(RowAction.pause), reason: s.name);
        expect(
          actionsFor(s),
          isNot(contains(RowAction.remove)),
          reason: s.name,
        );
      }
    });

    test('a paused download can be resumed, cancelled or removed', () {
      expect(actionsFor(DownloadStatus.paused), [
        RowAction.resume,
        RowAction.showInFinder,
        RowAction.copyUrl,
        RowAction.cancel,
        RowAction.remove,
      ]);
    });

    test('a failed download offers Retry', () {
      final a = actionsFor(DownloadStatus.failed);
      expect(a, contains(RowAction.retry));
      expect(a, isNot(contains(RowAction.resume)));
      expect(a, contains(RowAction.remove));
    });

    test('an expired link offers Refresh link, and not Retry', () {
      final a = actionsFor(DownloadStatus.needsRefresh);
      expect(a, contains(RowAction.refreshLink));
      expect(a, isNot(contains(RowAction.retry)));
      expect(a, isNot(contains(RowAction.resume)));
    });

    test(
      'a completed download can be opened, shown and deleted, not cancelled',
      () {
        expect(actionsFor(DownloadStatus.completed), [
          RowAction.showInFinder,
          RowAction.open,
          RowAction.copyUrl,
          RowAction.remove,
          RowAction.deleteFile,
        ]);
      },
    );

    test('only actions that make sense for the status ever appear', () {
      for (final s in DownloadStatus.values) {
        final a = actionsFor(s);
        expect(
          a.contains(RowAction.open),
          s == DownloadStatus.completed,
          reason: s.name,
        );
        expect(
          a.contains(RowAction.deleteFile),
          s == DownloadStatus.completed,
          reason: s.name,
        );
        expect(
          a.contains(RowAction.cancel),
          s != DownloadStatus.completed,
          reason: s.name,
        );
        expect(a.contains(RowAction.copyUrl), isTrue, reason: s.name);
      }
    });

    test('nothing selected offers nothing', () {
      expect(availableActions(const []), isEmpty);
    });
  });

  group('a selection of several', () {
    final mixed = [
      dl('run', DownloadStatus.downloading),
      dl('hold', DownloadStatus.paused),
      dl('done', DownloadStatus.completed),
      dl('bad', DownloadStatus.failed),
    ];

    test('offers an action if it fits any of them', () {
      final a = availableActions(mixed);
      expect(
        a,
        containsAll([
          RowAction.pause,
          RowAction.resume,
          RowAction.retry,
          RowAction.cancel,
          RowAction.remove,
          RowAction.deleteFile,
          RowAction.copyUrl,
        ]),
      );
    });

    test('single-download actions need exactly one selected', () {
      final a = availableActions(mixed);
      expect(a, isNot(contains(RowAction.showInFinder)));
      expect(a, isNot(contains(RowAction.open)));
      expect(a, isNot(contains(RowAction.refreshLink)));
    });

    test('applies each action only to the downloads it fits', () {
      List<String> ids(RowAction a) =>
          appliesTo(a, mixed).map((d) => d.id).toList();
      expect(ids(RowAction.pause), ['run']);
      expect(ids(RowAction.resume), ['hold']);
      expect(ids(RowAction.retry), ['bad']);
      expect(ids(RowAction.cancel), ['run', 'hold', 'bad']);
      expect(ids(RowAction.remove), ['hold', 'done', 'bad']);
      expect(ids(RowAction.deleteFile), ['done']);
      expect(ids(RowAction.copyUrl), ['run', 'hold', 'done', 'bad']);
    });
  });

  group('pausing a download that cannot resume', () {
    test('warns only when progress would be lost', () {
      final lossy = dl(
        'a',
        DownloadStatus.downloading,
        resumable: false,
        done: 50,
      );
      final fresh = dl(
        'b',
        DownloadStatus.downloading,
        resumable: false,
        done: 0,
      );
      final fine = dl('c', DownloadStatus.downloading, done: 50);
      final paused = dl('d', DownloadStatus.paused, resumable: false, done: 50);
      expect(
        losesProgressIfPaused([lossy, fresh, fine, paused]).map((d) => d.id),
        ['a'],
      );
    });
  });

  group('the menu', () {
    List<String> labels(List<HaulMenuEntry> entries) => [
      for (final e in entries)
        if (e is HaulMenuItem) e.label else '---',
    ];

    test('groups the actions, with dividers between groups', () {
      final entries = buildRowMenu([dl('a', DownloadStatus.paused)], (_) {});
      expect(labels(entries), [
        'Resume',
        '---',
        'Show in ${PlatformNames.fileManager}',
        'Copy URL',
        '---',
        'Cancel download…',
        'Remove from list',
      ]);
    });

    test('a completed download has Open and Delete file', () {
      final entries = buildRowMenu([dl('a', DownloadStatus.completed)], (_) {});
      expect(labels(entries), [
        'Show in ${PlatformNames.fileManager}',
        'Open',
        'Copy URL',
        '---',
        'Remove from list',
        'Delete file…',
      ]);
    });

    test('cancel and delete are marked destructive, nothing else is', () {
      final entries = buildRowMenu([
        dl('a', DownloadStatus.completed),
        dl('b', DownloadStatus.paused),
      ], (_) {});
      final danger = [
        for (final e in entries)
          if (e is HaulMenuItem && e.destructive) e.label,
      ];
      expect(danger, ['Cancel download…', 'Delete file…']);
    });

    test('there is never a divider at the start, end or twice in a row', () {
      for (final s in DownloadStatus.values) {
        final entries = buildRowMenu([dl('a', s)], (_) {});
        expect(entries.first, isA<HaulMenuItem>(), reason: s.name);
        expect(entries.last, isA<HaulMenuItem>(), reason: s.name);
        for (var i = 1; i < entries.length; i++) {
          expect(
            entries[i] is HaulMenuDivider && entries[i - 1] is HaulMenuDivider,
            isFalse,
            reason: s.name,
          );
        }
      }
    });

    test('choosing an item runs its action', () {
      RowAction? ran;
      final entries = buildRowMenu([
        dl('a', DownloadStatus.downloading),
      ], (a) => ran = a);
      final pause = entries.whereType<HaulMenuItem>().firstWhere(
        (i) => i.label == 'Pause',
      );
      pause.onSelected!();
      expect(ran, RowAction.pause);
    });

    test('an empty selection has an empty menu', () {
      expect(buildRowMenu(const [], (_) {}), isEmpty);
    });
  });

  group('moving a file to the Trash', () {
    late Directory dir;
    late Directory trash;
    late MacOSPlatformServices platform;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('trash_test_');
      trash = Directory('${dir.path}/Trash');
      platform = MacOSPlatformServices(trashDirectory: trash);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('moves the file, so it can be got back', () async {
      final file = File('${dir.path}/movie.mp4')..writeAsStringSync('data');
      await platform.moveToTrash(file.path);
      expect(file.existsSync(), isFalse);
      expect(File('${trash.path}/movie.mp4').readAsStringSync(), 'data');
    });

    test('never overwrites something already in the Trash', () async {
      File('${trash.path}/a.zip')
        ..createSync(recursive: true)
        ..writeAsStringSync('old');
      final file = File('${dir.path}/a.zip')..writeAsStringSync('new');
      await platform.moveToTrash(file.path);
      expect(File('${trash.path}/a.zip').readAsStringSync(), 'old');
      expect(File('${trash.path}/a 2.zip').readAsStringSync(), 'new');

      final third = File('${dir.path}/a.zip')..writeAsStringSync('third');
      await platform.moveToTrash(third.path);
      expect(File('${trash.path}/a 3.zip').readAsStringSync(), 'third');
    });

    test('a file that is already gone is not an error', () async {
      await platform.moveToTrash('${dir.path}/nothing.bin');
      expect(trash.existsSync() ? trash.listSync() : const [], isEmpty);
    });

    test('works for names without an extension', () async {
      final file = File('${dir.path}/README')..writeAsStringSync('x');
      File('${trash.path}/README')
        ..createSync(recursive: true)
        ..writeAsStringSync('y');
      await platform.moveToTrash(file.path);
      expect(File('${trash.path}/README 2').existsSync(), isTrue);
    });
  });
}
