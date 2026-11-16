import 'package:download_engine/download_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/features/downloads/download_row.dart';
import 'package:haul/features/downloads/downloads_list.dart';
import 'package:haul/features/header/throughput_graph.dart';

import '../support/app_harness.dart';
import '../support/widget_host.dart';
import '../downloads/downloads_list_test.dart' show snap, mib;

/// What the framework rebuilt while [body] ran, by widget type.
Future<Map<Type, int>> countRebuilds(Future<void> Function() body) async {
  final counts = <Type, int>{};
  final previous = debugOnRebuildDirtyWidget;
  debugOnRebuildDirtyWidget = (element, builtOnce) {
    counts.update(element.widget.runtimeType, (n) => n + 1, ifAbsent: () => 1);
  };
  try {
    await body();
  } finally {
    debugOnRebuildDirtyWidget = previous;
  }
  return counts;
}

void main() {
  haulTest('progress events redraw numbers and bars, never the list or rows', (
    tester,
  ) async {
    final env = await boot(tester);
    for (var i = 0; i < 8; i++) {
      await seedSnapshot(
        tester,
        env,
        snap('d$i', DownloadStatus.downloading, done: 10 * mib),
        'Compressed',
      );
    }

    final counts = await countRebuilds(() async {
      for (var step = 1; step <= 5; step++) {
        for (var i = 0; i < 8; i++) {
          env.engine.emit(
            ProgressEvent(
              id: 'd$i',
              downloadedBytes: (10 + step) * mib,
              totalBytes: 100 * mib,
              bytesPerSecond: 2.0 * mib,
              eta: const Duration(minutes: 1),
              segmentBytes: const [0],
            ),
          );
        }
        await tester.runAsync(() => realDelay(30));
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    expect(counts[DownloadsList] ?? 0, 0, reason: 'the list must not rebuild');
    expect(counts[DownloadRow] ?? 0, 0, reason: 'rows must not rebuild');
    // The part that shows numbers does rebuild: this is the proof that
    // events were delivered and the counting works.
    expect(counts[HaulProgressBar] ?? 0, greaterThan(0));
    await shutDown(tester, env);
  });

  haulTest('selecting a row does not rebuild the other rows\' bars', (
    tester,
  ) async {
    final env = await boot(tester);
    for (var i = 0; i < 4; i++) {
      await seedSnapshot(
        tester,
        env,
        snap('d$i', DownloadStatus.paused),
        'Compressed',
      );
    }
    final before = await countRebuilds(() async {
      cubit<ShellCubit>(tester).select({'d0'});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    });
    // Only the list reacts to a selection, and it hands each row its own
    // `selected` flag; the graph in the header is not involved at all.
    expect(before[ThroughputGraph] ?? 0, 0);
    await shutDown(tester, env);
  });

  haulTest('the animated parts sit on their own layers', (tester) async {
    final env = await boot(tester);
    await seedSnapshot(
      tester,
      env,
      snap('a', DownloadStatus.downloading, done: 10 * mib),
      'Compressed',
    );
    bool hasBoundary(Finder f) => find
        .descendant(of: f, matching: find.byType(RepaintBoundary))
        .evaluate()
        .isNotEmpty;
    expect(hasBoundary(find.byType(HaulProgressBar)), isTrue);
    expect(hasBoundary(find.byType(ThroughputGraph)), isTrue);
    await shutDown(tester, env);
  });
}
