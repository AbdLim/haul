import 'package:download_engine/download_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/app/error_text.dart';
import 'package:haul/data/downloads_dao.dart';
import 'package:haul/features/downloads/list_logic.dart';
import 'package:haul/features/downloads/row_text.dart';

const mib = 1024 * 1024;

StoredDownload dl(
  String id, {
  DownloadStatus status = DownloadStatus.paused,
  String? name,
  int? category,
  String url = 'https://example.com/file.bin',
}) => StoredDownload(
  snapshot: DownloadSnapshot(
    request: DownloadRequest(id: id, url: Uri.parse(url), saveDir: '/d'),
    status: status,
    fileName: name ?? '$id.bin',
  ),
  source: 'manual',
  createdAt: DateTime.utc(2026),
  categoryId: category,
);

DownloadSnapshot snap(
  DownloadStatus status, {
  int? total = 100 * mib,
  int done = 0,
  bool resumable = true,
  DownloadError? error,
}) => DownloadSnapshot(
  request: DownloadRequest(
    id: 'a',
    url: Uri.parse('https://example.com/some/archive.zip'),
    saveDir: '/d',
  ),
  status: status,
  fileName: 'archive.zip',
  totalBytes: total,
  resumable: resumable,
  error: error,
  segments: [
    if (total != null)
      Segment(id: 0, start: 0, end: total - 1, downloaded: done)
    else
      Segment(id: 0, start: 0, end: 0, downloaded: done),
  ],
);

ProgressEvent live({
  double speed = 0,
  int done = 0,
  int? total = 100 * mib,
  Duration? eta,
}) => ProgressEvent(
  id: 'a',
  downloadedBytes: done,
  totalBytes: total,
  bytesPerSecond: speed,
  eta: eta,
  segmentBytes: const [0],
);

void main() {
  group('rowSubtitle', () {
    test('queued and connecting say so in words', () {
      expect(
        rowSubtitle(snap(DownloadStatus.queued), null),
        'Waiting in the queue',
      );
      expect(rowSubtitle(snap(DownloadStatus.probing), null), 'Connecting…');
    });

    test('a running download shows sizes, speed and time left', () {
      final text = rowSubtitle(
        snap(DownloadStatus.downloading),
        live(
          speed: 4.2 * mib,
          done: 25 * mib,
          eta: const Duration(seconds: 62),
        ),
      );
      expect(text, '25.0 MB of 100 MB · 4.20 MB/s · 1m 02s left');
    });

    test('live bytes win over the last stored ones while running', () {
      final text = rowSubtitle(
        snap(DownloadStatus.downloading, done: mib),
        live(speed: mib.toDouble(), done: 50 * mib),
      );
      expect(text, startsWith('50.0 MB of 100 MB'));
    });

    test('without a speed yet it shows just the sizes', () {
      expect(
        rowSubtitle(snap(DownloadStatus.downloading, done: 10 * mib), null),
        '10.0 MB of 100 MB',
      );
    });

    test('an unknown total shows only what has arrived', () {
      final text = rowSubtitle(
        snap(DownloadStatus.downloading, total: null, done: 3 * mib),
        live(speed: mib.toDouble(), done: 3 * mib, total: null),
      );
      expect(text, '3.00 MB · 1.00 MB/s');
    });

    test('paused shows how far it got', () {
      expect(
        rowSubtitle(snap(DownloadStatus.paused, done: 30 * mib), null),
        'Paused · 30.0 MB of 100 MB',
      );
    });

    test('a paused download that cannot resume says it will start over', () {
      expect(
        rowSubtitle(
          snap(DownloadStatus.paused, done: 30 * mib, resumable: false),
          null,
        ),
        'Paused · will start over when resumed',
      );
    });

    test('completed shows the size', () {
      expect(
        rowSubtitle(snap(DownloadStatus.completed, done: 100 * mib), null),
        'Completed · 100 MB',
      );
      expect(
        rowSubtitle(snap(DownloadStatus.completed, total: null), null),
        'Completed',
      );
    });

    test('failed shows plain words, never a code', () {
      for (final code in DownloadErrorCode.values) {
        final text = rowSubtitle(
          snap(DownloadStatus.failed, error: DownloadError(code, 'raw $code')),
          null,
        );
        expect(text, isNot(contains('raw')), reason: code.name);
        // No camelCase identifier such as notFound or authRequired.
        expect(text, isNot(matches(RegExp(r'[a-z][A-Z]'))), reason: code.name);
        expect(text, plainError(DownloadError(code, '')));
        expect(text, isNotEmpty);
      }
    });

    test('an expired link says how to fix it', () {
      expect(
        rowSubtitle(snap(DownloadStatus.needsRefresh), null),
        'Link expired · needs a fresh link',
      );
    });

    test('all seven statuses have text', () {
      for (final s in DownloadStatus.values) {
        expect(rowSubtitle(snap(s), null), isNotEmpty, reason: s.name);
      }
    });
  });

  group('rowProgress and tone', () {
    test('is the share done, clamped, null without a size', () {
      expect(
        rowProgress(snap(DownloadStatus.paused, done: 25 * mib), null),
        0.25,
      );
      expect(
        rowProgress(snap(DownloadStatus.paused, total: null), null),
        isNull,
      );
      expect(
        rowProgress(snap(DownloadStatus.paused, done: 500 * mib), null),
        1,
      );
      expect(rowProgress(snap(DownloadStatus.completed), null), 1);
    });

    test('a running download uses the live count', () {
      expect(
        rowProgress(snap(DownloadStatus.downloading), live(done: 40 * mib)),
        0.4,
      );
    });

    test('each state has a colour', () {
      expect(rowTone(DownloadStatus.downloading), isNotNull);
      expect(rowTone(DownloadStatus.completed).name, 'success');
      expect(rowTone(DownloadStatus.failed).name, 'danger');
      expect(rowTone(DownloadStatus.needsRefresh).name, 'danger');
      expect(rowTone(DownloadStatus.paused).name, 'neutral');
      expect(rowTone(DownloadStatus.downloading).name, 'accent');
    });
  });

  group('rowTitle', () {
    test('uses the file name, then the end of the link, then the host', () {
      expect(rowTitle(snap(DownloadStatus.paused)), 'archive.zip');
      final unnamed = DownloadSnapshot(
        request: DownloadRequest(
          id: 'x',
          url: Uri.parse('https://example.com/dir/thing.iso'),
          saveDir: '/d',
        ),
      );
      expect(rowTitle(unnamed), 'thing.iso');
      final bare = DownloadSnapshot(
        request: DownloadRequest(
          id: 'y',
          url: Uri.parse('https://example.com/'),
          saveDir: '/d',
        ),
      );
      expect(rowTitle(bare), 'example.com');
    });
  });

  group('visibleDownloads', () {
    final all = [
      dl(
        'a',
        status: DownloadStatus.downloading,
        category: 1,
        name: 'ubuntu.iso',
      ),
      dl('b', status: DownloadStatus.paused, category: 1, name: 'movie.mp4'),
      dl(
        'c',
        status: DownloadStatus.completed,
        category: 2,
        name: 'Report.PDF',
      ),
      dl('d', status: DownloadStatus.failed, category: 2, name: 'song.mp3'),
    ];

    test('is newest first', () {
      expect(visibleDownloads(all, const ShellState()).map((d) => d.id), [
        'd',
        'c',
        'b',
        'a',
      ]);
    });

    test('a status filter keeps matching statuses', () {
      final active = visibleDownloads(
        all,
        const ShellState(status: StatusFilter.active),
      );
      expect(active.map((d) => d.id), ['a']);
      final failed = visibleDownloads(
        all,
        const ShellState(status: StatusFilter.failed),
      );
      expect(failed.map((d) => d.id), ['d']);
    });

    test('a category filter keeps that category', () {
      expect(
        visibleDownloads(all, const ShellState(categoryId: 2)).map((d) => d.id),
        ['d', 'c'],
      );
    });

    test('search matches the name, ignoring case', () {
      expect(
        visibleDownloads(
          all,
          const ShellState(query: 'REPORT'),
        ).map((d) => d.id),
        ['c'],
      );
    });

    test('search matches the link too', () {
      final list = [
        dl(
          'z',
          url: 'https://mirror.example.org/pub/ubuntu-24.iso',
          name: 'x.bin',
        ),
      ];
      expect(
        visibleDownloads(list, const ShellState(query: 'mirror')),
        hasLength(1),
      );
    });

    test('search narrows a filter rather than replacing it', () {
      expect(
        visibleDownloads(
          all,
          const ShellState(categoryId: 1, query: 'movie'),
        ).map((d) => d.id),
        ['b'],
      );
      expect(
        visibleDownloads(
          all,
          const ShellState(status: StatusFilter.paused, query: 'ubuntu'),
        ),
        isEmpty,
      );
    });

    test('blank search shows everything', () {
      expect(
        visibleDownloads(all, const ShellState(query: '   ')),
        hasLength(4),
      );
    });
  });

  group('clickRow', () {
    const order = ['a', 'b', 'c', 'd', 'e'];

    SelectionResult click(
      String id, {
      Set<String> current = const {},
      String? anchor,
      bool command = false,
      bool shift = false,
    }) => clickRow(
      order: order,
      current: current,
      anchor: anchor,
      clicked: id,
      command: command,
      shift: shift,
    );

    test('a plain click selects only that row', () {
      final r = click('c', current: {'a', 'b'});
      expect(r.selection, {'c'});
      expect(r.anchor, 'c');
    });

    test('Command-click adds a row, and removes it again', () {
      var r = click('b', current: {'a'}, command: true);
      expect(r.selection, {'a', 'b'});
      r = click('b', current: r.selection, command: true);
      expect(r.selection, {'a'});
    });

    test('Shift-click selects from the anchor, in either direction', () {
      expect(click('d', current: {'b'}, anchor: 'b', shift: true).selection, {
        'b',
        'c',
        'd',
      });
      expect(click('a', current: {'c'}, anchor: 'c', shift: true).selection, {
        'a',
        'b',
        'c',
      });
    });

    test('Shift-click keeps the anchor so the range can be redrawn', () {
      final first = click('d', current: {'b'}, anchor: 'b', shift: true);
      final second = click(
        'c',
        current: first.selection,
        anchor: first.anchor,
        shift: true,
      );
      expect(second.selection, {'b', 'c'});
      expect(second.anchor, 'b');
    });

    test('Shift-click with no anchor acts like a plain click', () {
      expect(click('c', shift: true).selection, {'c'});
    });

    test('Command and Shift together add the range', () {
      final r = click(
        'd',
        current: {'a', 'c'},
        anchor: 'c',
        shift: true,
        command: true,
      );
      expect(r.selection, {'a', 'c', 'd'});
    });
  });
}
