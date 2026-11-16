import 'dart:async';
import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

/// A server that accepts the connection and then never says anything.
void main() {
  late Directory dir;
  late ServerSocket silent;
  late HttpClient client;
  final held = <Socket>[];

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('silent_');
    client = HttpClient()..autoUncompress = false;
    silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    silent.listen(held.add);
  });
  tearDown(() async {
    client.close(force: true);
    for (final s in held) {
      s.destroy();
    }
    held.clear();
    await silent.close();
    dir.deleteSync(recursive: true);
  });

  DownloadTask task({Duration stall = const Duration(seconds: 30)}) =>
      DownloadTask(
        client: client,
        stallTimeout: stall,
        retryDelays: const [Duration.zero],
        maxFailures: 2,
        snapshot: DownloadSnapshot(
          request: DownloadRequest(
            id: 's',
            url: Uri.parse('http://127.0.0.1:${silent.port}/file.bin'),
            saveDir: dir.path,
          ),
        ),
      );

  test('pausing a download that is still connecting stops it at once', () async {
    final t = task();
    final run = t.run();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await t.pause().timeout(const Duration(seconds: 3));
    final result = await run.timeout(const Duration(seconds: 3));
    expect(result.status, DownloadStatus.paused);
  });

  test('a server that never answers fails after the timeout', () async {
    final t = task(stall: const Duration(milliseconds: 300));
    final result = await t.run().timeout(const Duration(seconds: 5));
    expect(result.status, DownloadStatus.failed);
    expect(result.error?.code, DownloadErrorCode.network);
  });

  test('the engine can pause and cancel a connecting download', () async {
    final engine = DownloadEngine(retryDelays: const [Duration.zero]);
    final events = <EngineEvent>[];
    engine.events.listen(events.add);
    DownloadStatus? last(String id) => events
        .whereType<SnapshotEvent>()
        .where((e) => e.snapshot.id == id)
        .map((e) => e.snapshot.status)
        .lastOrNull;

    for (final id in ['p', 'c']) {
      engine.add(
        DownloadRequest(
          id: id,
          url: Uri.parse('http://127.0.0.1:${silent.port}/$id.bin'),
          saveDir: dir.path,
        ),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(last('p'), DownloadStatus.probing);
    engine.pause('p');
    engine.cancel('c');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(last('p'), DownloadStatus.paused);
    expect(events.whereType<RemovedEvent>().map((e) => e.id), contains('c'));
    await engine.dispose();
  });
}
