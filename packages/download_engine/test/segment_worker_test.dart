import 'dart:async';
import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:download_engine/src/segment_worker.dart';
import 'package:test/test.dart';

import '../test_support/range_server.dart';

void main() {
  late Directory dir;
  late HttpClient client;
  late RangeServer server;
  late FileWriter writer;
  late String path;

  Future<void> setUpFor(int size, {int? throttle}) async {
    server = await RangeServer.start(size: size, throttleBytesPerSec: throttle);
    path = '${dir.path}/out.part';
    writer = await FileWriter.create(path, size);
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('worker_');
    client = HttpClient()..autoUncompress = false;
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
    dir.deleteSync(recursive: true);
  });

  DownloadRequest req() =>
      DownloadRequest(id: 't', url: server.url, saveDir: dir.path);

  SegmentWorker worker(
    SegmentState s, {
    String? etag,
    void Function(int)? onBytes,
  }) => SegmentWorker(
    client: client,
    request: req(),
    url: server.url,
    segment: s,
    writer: writer,
    etag: etag,
    onBytes: onBytes,
    stallTimeout: const Duration(seconds: 5),
  );

  test('downloads exactly its range and nothing else', () async {
    await setUpFor(300000);
    final seg = SegmentState(id: 0, start: 100000, end: 199999);
    var counted = 0;
    await worker(seg, onBytes: (n) => counted += n).run();
    await writer.close();

    expect(seg.downloaded, 100000);
    expect(counted, 100000);
    final file = File(path).readAsBytesSync();
    expect(file.sublist(100000, 200000), server.bytes(100000, 199999));
    expect(file.sublist(0, 100000).every((b) => b == 0), isTrue);
    expect(file.sublist(200000).every((b) => b == 0), isTrue);
    expect(server.log.single.range, 'bytes=100000-199999');
  });

  test('continues from where it stopped', () async {
    await setUpFor(100000);
    final seg = SegmentState(id: 0, start: 0, end: 99999, downloaded: 40000);
    await writer.write(0, server.bytes(0, 39999));
    await worker(seg).run();
    await writer.close();

    expect(server.log.single.range, 'bytes=40000-99999');
    expect(File(path).readAsBytesSync(), server.bytes(0, 99999));
  });

  test('stops at a lowered end while the server is still sending', () async {
    await setUpFor(4 * 1024 * 1024, throttle: 2 * 1024 * 1024);
    final seg = SegmentState(id: 0, start: 0, end: 4 * 1024 * 1024 - 1);
    final w = worker(seg);
    final run = w.run();

    // Let a little arrive, then hand the tail to "another worker".
    while (seg.downloaded < 200 * 1024) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    const newEnd = 1024 * 1024 - 1;
    seg.end = newEnd;
    await run;
    await writer.close();

    expect(seg.downloaded, 1024 * 1024);
    final file = File(path).readAsBytesSync();
    expect(file.sublist(0, newEnd + 1), server.bytes(0, newEnd));
    // Nothing was written past the new end.
    expect(file.sublist(newEnd + 1).every((b) => b == 0), isTrue);
    // And the server was cut off well before it finished.
    expect(server.log.single.bytesSent, lessThan(4 * 1024 * 1024));
  });

  test('a 200 response raises rangeIgnored', () async {
    await setUpFor(10000);
    server.noRanges = true;
    final seg = SegmentState(id: 0, start: 1000, end: 4999);
    await expectLater(
      worker(seg).run(),
      throwsA(
        isA<DownloadError>().having(
          (e) => e.code,
          'code',
          DownloadErrorCode.rangeIgnored,
        ),
      ),
    );
    expect(seg.downloaded, 0);
    await writer.close();
  });

  test('a 200 after sending If-Range means the file changed', () async {
    await setUpFor(10000);
    final old = server.etag;
    server.changeEtag();
    final seg = SegmentState(id: 0, start: 0, end: 9999);
    await expectLater(
      worker(seg, etag: old).run(),
      throwsA(
        isA<DownloadError>().having(
          (e) => e.code,
          'code',
          DownloadErrorCode.fileChanged,
        ),
      ),
    );
    expect(server.log.single.headers['if-range'], old);
    await writer.close();
  });

  test('weak ETags are never sent in If-Range', () async {
    await setUpFor(1000);
    final seg = SegmentState(id: 0, start: 0, end: 999);
    await worker(seg, etag: 'W/"weak"').run();
    expect(server.log.single.headers.containsKey('if-range'), isFalse);
    await writer.close();
  });

  test('cancel stops the transfer without an error', () async {
    await setUpFor(4 * 1024 * 1024, throttle: 1024 * 1024);
    final seg = SegmentState(id: 0, start: 0, end: 4 * 1024 * 1024 - 1);
    final w = worker(seg);
    final run = w.run();
    while (seg.downloaded < 100 * 1024) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    w.cancel();
    await run;
    await writer.close();
    expect(seg.downloaded, lessThan(4 * 1024 * 1024));
    expect(seg.isComplete, isFalse);
  });

  test('5xx is a retryable error, 404 is not', () async {
    await setUpFor(1000);
    final seg = SegmentState(id: 0, start: 0, end: 999);
    server.forceStatus = 503;
    await expectLater(
      worker(seg).run(),
      throwsA(
        isA<DownloadError>().having((e) => e.retryable, 'retryable', true),
      ),
    );
    server.forceStatus = 404;
    await expectLater(
      worker(seg).run(),
      throwsA(
        isA<DownloadError>().having((e) => e.retryable, 'retryable', false),
      ),
    );
    await writer.close();
  });

  test(
    'a connection dropped mid-segment is retryable and keeps progress',
    () async {
      await setUpFor(200000);
      server.dropAfterBytes = 50000;
      final seg = SegmentState(id: 0, start: 0, end: 199999);
      await expectLater(
        worker(seg).run(),
        throwsA(
          isA<DownloadError>().having((e) => e.retryable, 'retryable', true),
        ),
      );
      expect(seg.downloaded, 50000);
      await writer.close();
    },
  );

  test('the throttle hook runs before every write', () async {
    await setUpFor(100000);
    final seg = SegmentState(id: 0, start: 0, end: 99999);
    var asked = 0;
    final w = SegmentWorker(
      client: client,
      request: req(),
      url: server.url,
      segment: seg,
      writer: writer,
      throttle: (n) async => asked += n,
    );
    await w.run();
    expect(asked, 100000);
    await writer.close();
  });
}
