import 'dart:async';

import 'package:download_engine/download_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/cubits/downloads_cubit.dart';
import 'package:haul/app/cubits/throughput_cubit.dart';

import '../support/test_deps.dart';

const mib = 1024 * 1024;

DownloadSnapshot snap(String id, DownloadStatus status) => DownloadSnapshot(
  request: DownloadRequest(
    id: id,
    url: Uri.parse('https://e.com/$id'),
    saveDir: '/d',
  ),
  status: status,
  fileName: '$id.bin',
);

ProgressEvent progress(
  String id,
  double speed, {
  int? total = 100 * mib,
  int done = 0,
}) => ProgressEvent(
  id: id,
  downloadedBytes: done,
  totalBytes: total,
  bytesPerSecond: speed,
  segmentBytes: const [0],
);

Future<void> settle([int ms = 150]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late FakeEngine engine;
  late DownloadsCubit downloads;
  late LiveCubit live;
  late ThroughputCubit cubit;
  late dynamic deps;
  late StreamController<void> ticks;
  late DateTime now;

  setUp(() async {
    final t = await makeTestDeps();
    deps = t.deps;
    engine = t.engine;
    downloads = DownloadsCubit(t.deps.downloads, t.deps.categories);
    live = LiveCubit(t.deps.downloads);
    ticks = StreamController<void>.broadcast();
    now = DateTime.utc(2026, 4, 20, 12);
    cubit = ThroughputCubit(
      live: live,
      downloads: downloads,
      ticks: ticks.stream,
      clock: () => now,
    );
  });
  tearDown(() async {
    await cubit.close();
    await live.close();
    await downloads.close();
    await ticks.close();
    await deps.dispose();
  });

  Future<void> run(String id, DownloadStatus s) async {
    engine.emit(SnapshotEvent(snap(id, s)));
    await settle();
  }

  test('starts idle with a flat history of the right length', () {
    expect(cubit.state.idle, isTrue);
    expect(cubit.state.samples, hasLength(throughputSamples));
    expect(cubit.state.samples.every((s) => s == 0), isTrue);
    expect(cubit.state.speed, 0);
  });

  test('a tick records the combined speed of what is running', () async {
    await run('a', DownloadStatus.downloading);
    await run('b', DownloadStatus.downloading);
    engine.emit(progress('a', 3.0 * mib));
    engine.emit(progress('b', 2.0 * mib));
    await settle();

    cubit.sample();
    expect(cubit.state.speed, 5.0 * mib);
    expect(cubit.state.activeCount, 2);
    expect(cubit.state.idle, isFalse);
    expect(cubit.state.samples.last, 5.0 * mib);
    expect(cubit.state.lastSampleAt, now);
  });

  test('samples shift along and keep a fixed length', () async {
    await run('a', DownloadStatus.downloading);
    for (final speed in [1.0, 2.0, 3.0]) {
      engine.emit(progress('a', speed * mib));
      await settle();
      cubit.sample();
    }
    final s = cubit.state.samples;
    expect(s, hasLength(throughputSamples));
    expect(s.sublist(throughputSamples - 3), [1.0 * mib, 2.0 * mib, 3.0 * mib]);
    expect(s.first, 0);
  });

  test('the speed tracks the real one within a tick', () async {
    await run('a', DownloadStatus.downloading);
    engine.emit(progress('a', 8.0 * mib));
    await settle();
    cubit.sample();
    expect(cubit.state.speed, 8.0 * mib);

    engine.emit(progress('a', 1.0 * mib));
    await settle();
    cubit.sample();
    expect(cubit.state.speed, 1.0 * mib);
  });

  test(
    'when everything stops the very next tick shows nothing stale',
    () async {
      await run('a', DownloadStatus.downloading);
      engine.emit(progress('a', 6.0 * mib));
      await settle();
      cubit.sample();
      expect(cubit.state.speed, greaterThan(0));

      await run('a', DownloadStatus.paused);
      cubit.sample();
      expect(cubit.state.speed, 0);
      expect(cubit.state.activeCount, 0);
      expect(cubit.state.idle, isTrue);
      expect(cubit.state.eta, isNull);
      expect(cubit.state.samples.last, 0);
    },
  );

  test(
    'a download that is not running adds nothing, even with old numbers',
    () async {
      await run('a', DownloadStatus.downloading);
      await run('b', DownloadStatus.paused);
      engine.emit(progress('a', 2.0 * mib));
      engine.emit(progress('b', 9.0 * mib)); // stale
      await settle();
      cubit.sample();
      expect(cubit.state.speed, 2.0 * mib);
      expect(cubit.state.activeCount, 1);
    },
  );

  test('queued downloads are not running', () async {
    await run('a', DownloadStatus.queued);
    cubit.sample();
    expect(cubit.state.activeCount, 0);
    expect(cubit.state.idle, isTrue);
  });

  test('connecting counts as active even before bytes flow', () async {
    await run('a', DownloadStatus.probing);
    cubit.sample();
    expect(cubit.state.activeCount, 1);
    expect(cubit.state.speed, 0);
    expect(cubit.state.idle, isFalse);
  });

  test('time left is everything remaining over the combined speed', () async {
    await run('a', DownloadStatus.downloading);
    await run('b', DownloadStatus.downloading);
    engine.emit(progress('a', 4.0 * mib, total: 100 * mib, done: 60 * mib));
    engine.emit(progress('b', 6.0 * mib, total: 200 * mib, done: 100 * mib));
    await settle();
    cubit.sample();
    // 40 + 100 MiB left at 10 MiB/s.
    expect(cubit.state.eta, const Duration(seconds: 14));
  });

  test('time left is unknown when no size is known or nothing moves', () async {
    await run('a', DownloadStatus.downloading);
    engine.emit(progress('a', 4.0 * mib, total: null));
    await settle();
    cubit.sample();
    expect(cubit.state.eta, isNull);

    engine.emit(progress('a', 0, total: 100 * mib));
    await settle();
    cubit.sample();
    expect(cubit.state.eta, isNull);
  });

  test('it samples on the ticker it was given', () async {
    await run('a', DownloadStatus.downloading);
    engine.emit(progress('a', 1.0 * mib));
    await settle();
    ticks.add(null);
    await settle(30);
    expect(cubit.state.speed, 1.0 * mib);
    expect(cubit.state.lastSampleAt, now);
  });
}
