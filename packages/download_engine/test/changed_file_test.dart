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
    dir = Directory.systemTemp.createTempSync('changed_');
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
  );

  Future<DownloadSnapshot> pausedAt40(int size) async {
    final task = taskFor(
      DownloadSnapshot(
        request: DownloadRequest(
          id: 't',
          url: server.url,
          saveDir: dir.path,
          maxConnections: 4,
        ),
      ),
    );
    final run = task.run();
    task.events.listen((e) {
      if (e is ProgressEvent && e.downloadedBytes >= size * 0.4) task.pause();
    });
    return run;
  }

  DownloadSnapshot stored(DownloadSnapshot s) => DownloadSnapshot.fromJson(
    jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>,
  );

  test('a changed ETag between pause and resume restarts from zero', () async {
    const size = 12 * mib;
    server = await RangeServer.start(size: size, throttleBytesPerSec: 2 * mib);
    final paused = await pausedAt40(size);
    expect(paused.status, DownloadStatus.paused);
    final oldBytes = server.allBytes;

    // The file on the server is replaced while we were paused.
    server.changeContent();
    server.throttleBytesPerSec = null;
    server.log.clear();

    final task = taskFor(stored(paused));
    final events = <EngineEvent>[];
    task.events.listen(events.add);
    final result = await task.run();
    await Future<void>.delayed(Duration.zero);

    expect(result.status, DownloadStatus.completed);
    expect(events.whereType<FileChangedEvent>(), hasLength(1));

    final out = File('${dir.path}/file.bin').readAsBytesSync();
    expect(out, server.allBytes); // the new content
    expect(out, isNot(oldBytes));
    expect(result.etag, server.etag); // new validator was picked up
    expect(File('${dir.path}/file.bin.part').existsSync(), isFalse);
  });

  test('an unchanged file resumes without a fileChanged event', () async {
    const size = 8 * mib;
    server = await RangeServer.start(size: size, throttleBytesPerSec: 2 * mib);
    final paused = await pausedAt40(size);
    server.throttleBytesPerSec = null;

    final task = taskFor(stored(paused));
    final events = <EngineEvent>[];
    task.events.listen(events.add);
    final result = await task.run();
    await Future<void>.delayed(Duration.zero);

    expect(result.status, DownloadStatus.completed);
    expect(events.whereType<FileChangedEvent>(), isEmpty);
    expect(File('${dir.path}/file.bin').readAsBytesSync(), server.allBytes);
  });

  test('every ranged request carries If-Range', () async {
    server = await RangeServer.start(size: 4 * mib);
    final r = await taskFor(
      DownloadSnapshot(
        request: DownloadRequest(
          id: 't',
          url: server.url,
          saveDir: dir.path,
          maxConnections: 4,
        ),
      ),
    ).run();
    expect(r.status, DownloadStatus.completed);
    final ranged = server.log.where((e) => e.range != 'bytes=0-0');
    expect(ranged, isNotEmpty);
    for (final e in ranged) {
      expect(e.headers['if-range'], server.etag);
    }
  });
}
