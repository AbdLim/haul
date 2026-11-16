import 'package:download_engine/download_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/dependencies.dart';
import 'package:haul/app/haul_app.dart';

import 'test_deps.dart';

Future<void> realDelay([int ms = 120]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

class Env {
  Env(this.deps, this.engine, this.categoryIds);
  final AppDependencies deps;
  final FakeEngine engine;
  final Map<String, int> categoryIds;
}

/// Adds a download in [category] and moves it to [status].
Future<void> seed(
  WidgetTester tester,
  Env env,
  String id,
  String category,
  DownloadStatus status,
) async {
  final request = DownloadRequest(
    id: id,
    url: Uri.parse('https://e.com/$id'),
    saveDir: '/d',
  );
  await tester.runAsync(() async {
    await env.deps.downloads.add(
      request,
      categoryId: env.categoryIds[category],
    );
    env.engine.emit(
      SnapshotEvent(
        DownloadSnapshot(request: request, status: status, fileName: '$id.bin'),
      ),
    );
    await realDelay();
  });
  // A list change takes two frames (rebuild, then the rows are inserted),
  // and then the row's own animation.
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<Env> boot(
  WidgetTester tester, {
  bool reduceMotion = false,
  int? bridgePort,
}) async {
  final t = (await tester.runAsync(
    () => makeTestDeps(bridgePort: bridgePort),
  ))!;
  final cats = (await tester.runAsync(() => t.deps.categories.all()))!;
  final env = Env(t.deps, t.engine, {for (final c in cats) c.name: c.id});
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Mounted inside runAsync so the cubits' database reads start in the real
  // zone, where they can complete.
  await tester.runAsync(() async {
    await tester.pumpWidget(HaulApp(deps: t.deps, native: false));
    await realDelay();
  });
  await tester.pump(const Duration(milliseconds: 300));
  return env;
}

Future<void> shutDown(WidgetTester tester, Env env) async {
  // Unmount and close inside runAsync, as the mount happened there.
  await tester.runAsync(() async {
    await tester.pumpWidget(const SizedBox());
    await realDelay(100);
    await env.deps.dispose();
  });
}

/// A cubit from the running app, found through the widget tree.
T cubit<T extends StateStreamableSource<Object?>>(WidgetTester tester) =>
    BlocProvider.of<T>(tester.element(find.byType(WidgetsApp)));

/// Like [seed], with a full snapshot (sizes, segments, an error...).
Future<void> seedSnapshot(
  WidgetTester tester,
  Env env,
  DownloadSnapshot snapshot,
  String category,
) async {
  await tester.runAsync(() async {
    await env.deps.downloads.add(
      snapshot.request,
      categoryId: env.categoryIds[category],
    );
    env.engine.emit(SnapshotEvent(snapshot));
    await realDelay();
  });
  // A list change takes two frames (rebuild, then the rows are inserted),
  // and then the row's own animation.
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Like [boot], with the system's Reduce Motion setting on.
Future<Env> bootReduced(WidgetTester tester) async {
  final t = (await tester.runAsync(makeTestDeps))!;
  final cats = (await tester.runAsync(() => t.deps.categories.all()))!;
  final env = Env(t.deps, t.engine, {for (final c in cats) c.name: c.id});
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(1200, 800),
          disableAnimations: true,
        ),
        child: HaulApp(deps: t.deps, native: false),
      ),
    );
    await realDelay();
  });
  await tester.pump(const Duration(milliseconds: 300));
  return env;
}
