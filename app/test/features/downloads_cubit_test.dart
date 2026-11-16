import 'package:download_engine/download_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/cubits/downloads_cubit.dart';

import '../support/test_deps.dart';

DownloadSnapshot snap(String id, DownloadStatus status, {int downloaded = 0}) =>
    DownloadSnapshot(
      request: DownloadRequest(
        id: id,
        url: Uri.parse('https://e.com/$id.zip'),
        saveDir: '/d',
      ),
      status: status,
      fileName: '$id.zip',
      totalBytes: 1000,
      supportsRanges: true,
      segments: [Segment(id: 0, start: 0, end: 999, downloaded: downloaded)],
    );

Future<void> settle([int ms = 120]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late FakeEngine engine;
  late DownloadsCubit cubit;
  late LiveCubit live;
  late dynamic deps;

  setUp(() async {
    final t = await makeTestDeps();
    deps = t.deps;
    engine = t.engine;
    cubit = DownloadsCubit(t.deps.downloads, t.deps.categories);
    live = LiveCubit(t.deps.downloads);
  });
  tearDown(() async {
    await cubit.close();
    await live.close();
    await deps.dispose();
  });

  test('is not loaded at first, then loaded with the six categories', () async {
    expect(cubit.state.loaded, isFalse);
    await settle();
    expect(cubit.state.loaded, isTrue);
    expect(cubit.state.categories.map((c) => c.name), contains('Video'));
    expect(cubit.state.downloads, isEmpty);
  });

  test('follows downloads as the engine reports them', () async {
    engine.emit(SnapshotEvent(snap('a', DownloadStatus.downloading)));
    engine.emit(SnapshotEvent(snap('b', DownloadStatus.paused)));
    await settle();
    expect(cubit.state.downloads.map((d) => d.id), containsAll(['a', 'b']));
    expect(cubit.state.byId('a')!.snapshot.status, DownloadStatus.downloading);
    expect(cubit.state.byId('zzz'), isNull);
  });

  test('pause all and resume all send the right commands', () async {
    engine.emit(SnapshotEvent(snap('run', DownloadStatus.downloading)));
    engine.emit(SnapshotEvent(snap('wait', DownloadStatus.queued)));
    engine.emit(SnapshotEvent(snap('hold', DownloadStatus.paused)));
    engine.emit(SnapshotEvent(snap('bad', DownloadStatus.failed)));
    engine.emit(SnapshotEvent(snap('old', DownloadStatus.needsRefresh)));
    engine.emit(SnapshotEvent(snap('done', DownloadStatus.completed)));
    await settle();

    cubit.pauseAll();
    final paused = engine.commands.whereType<PauseCommand>().map((c) => c.id);
    expect(paused, unorderedEquals(['run', 'wait']));

    engine.commands.clear();
    cubit.resumeAll();
    final resumed = engine.commands.whereType<ResumeCommand>().map((c) => c.id);
    // Paused and failed come back; an expired link needs a new URL instead.
    expect(resumed, unorderedEquals(['hold', 'bad']));
  });

  test('single actions go to the engine', () async {
    // Start-up sends the limits and network settings; only what follows counts.
    engine.commands.clear();
    cubit.pause('a');
    cubit.resume('a');
    cubit.cancel('a');
    cubit.remove('a');
    expect(engine.commands.map((c) => c.runtimeType), [
      PauseCommand,
      ResumeCommand,
      CancelCommand,
      RemoveCommand,
    ]);
  });

  group('LiveCubit', () {
    ProgressEvent progress(String id, double speed) => ProgressEvent(
      id: id,
      downloadedBytes: 10,
      bytesPerSecond: speed,
      segmentBytes: const [10],
    );

    test(
      'keeps the newest numbers per download and totals the speed',
      () async {
        engine.emit(SnapshotEvent(snap('a', DownloadStatus.downloading)));
        engine.emit(SnapshotEvent(snap('b', DownloadStatus.downloading)));
        await settle();
        engine.emit(progress('a', 100));
        engine.emit(progress('b', 50));
        engine.emit(progress('a', 300));
        await settle();
        expect(live.state['a']!.bytesPerSecond, 300);
        expect(live.totalSpeed, 350);
      },
    );

    test('forgets a download once it stops running', () async {
      engine.emit(SnapshotEvent(snap('a', DownloadStatus.downloading)));
      await settle();
      engine.emit(progress('a', 100));
      await settle();
      expect(live.state, contains('a'));

      engine.emit(SnapshotEvent(snap('a', DownloadStatus.paused)));
      await settle();
      expect(live.state, isNot(contains('a')));
      expect(live.totalSpeed, 0);
    });
  });
}
