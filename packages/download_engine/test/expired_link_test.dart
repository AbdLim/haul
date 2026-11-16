import 'dart:convert';
import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

import '../test_support/range_server.dart';

const mib = 1024 * 1024;

void main() {
  late Directory dir;
  late HttpClient client;
  late RangeServer server;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('expired_');
    client = HttpClient()
      ..autoUncompress = false
      ..maxConnectionsPerHost = 16;
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
    dir.deleteSync(recursive: true);
  });

  DownloadTask taskFor(DownloadSnapshot s) => DownloadTask(
    client: client,
    snapshot: s,
    stallTimeout: const Duration(seconds: 5),
    sleep: (_) async {},
  );

  DownloadSnapshot fresh() => DownloadSnapshot(
    request: DownloadRequest(
      id: 't',
      url: server.url,
      saveDir: dir.path,
      maxConnections: 4,
    ),
  );

  Future<DownloadSnapshot> expire({int code = 403}) async {
    server = await RangeServer.start(size: 8 * mib);
    // Connections keep getting cut, so workers must come back for more, and
    // after 3 MiB the link "expires".
    server.dropAfterBytes = 400 * 1024;
    server.statusAfterBytes = 3 * mib;
    server.statusAfterBytesCode = code;
    return taskFor(fresh()).run();
  }

  test(
    '403 after bytes arrived moves to needsRefresh and keeps the data',
    () async {
      final snap = await expire();
      expect(snap.status, DownloadStatus.needsRefresh);
      expect(snap.error!.code, DownloadErrorCode.forbidden);
      expect(snap.downloadedBytes, greaterThan(0));
      expect(snap.downloadedBytes, lessThan(8 * mib));
      expect(File(snap.partPath!).existsSync(), isTrue);
    },
  );

  test('410 does the same', () async {
    final snap = await expire(code: 410);
    expect(snap.status, DownloadStatus.needsRefresh);
    expect(snap.error!.code, DownloadErrorCode.gone);
  });

  test(
    'refreshing with a working link completes without refetching what is done',
    () async {
      final snap = await expire();
      expect(snap.status, DownloadStatus.needsRefresh);

      // A new link: same file, fresh signature.
      server.statusAfterBytes = null;
      server.dropAfterBytes = null;
      server.log.clear();
      final saved = DownloadSnapshot.fromJson(
        jsonDecode(jsonEncode(snap.toJson())) as Map<String, Object?>,
      );
      final refreshed = saved.withRefreshedUrl(
        server.url.replace(queryParameters: {'sig': 'fresh'}),
      );
      expect(refreshed.request.url.queryParameters['sig'], 'fresh');
      expect(refreshed.fileName, snap.fileName);
      expect(refreshed.segments.length, snap.segments.length);

      final result = await taskFor(refreshed).run();
      expect(
        result.status,
        DownloadStatus.completed,
        reason: '${result.error}',
      );
      expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);

      // Nothing inside an already finished segment is requested again.
      for (final s in saved.segments.where((s) => s.downloaded >= s.length)) {
        expect(
          server.log.where(
            (e) => e.rangeStart >= s.start && e.rangeStart <= s.end,
          ),
          isEmpty,
          reason: 'segment ${s.id} was complete',
        );
      }
      final fetched = server.log.fold<int>(0, (n, e) => n + e.bytesSent);
      expect(
        fetched,
        lessThanOrEqualTo(8 * mib - saved.downloadedBytes + 4 * mib),
      );
    },
  );

  test('403 before any byte arrived is a plain failure', () async {
    server = await RangeServer.start(size: 4 * mib);
    server.failAfterProbe = 403;
    final snap = await taskFor(fresh()).run();
    expect(snap.status, DownloadStatus.failed);
    expect(snap.error!.code, DownloadErrorCode.forbidden);
  });

  test(
    'refreshUrl keeps the old file name and segments, and clears the error',
    () {
      final snap = DownloadSnapshot(
        request: DownloadRequest(
          id: 'a',
          url: Uri.parse('https://e.com/a?sig=1'),
          saveDir: '/d',
        ),
        status: DownloadStatus.needsRefresh,
        fileName: 'a.bin',
        error: const DownloadError(DownloadErrorCode.forbidden, 'x'),
        segments: const [Segment(id: 0, start: 0, end: 9, downloaded: 5)],
      );
      final r = snap.withRefreshedUrl(
        Uri.parse('https://e.com/a?sig=2'),
        cookies: 'c=1',
      );
      expect(r.error, isNull);
      expect(r.request.cookies, 'c=1');
      expect(r.segments.single.downloaded, 5);
      expect(r.status, DownloadStatus.queued);
    },
  );
}
