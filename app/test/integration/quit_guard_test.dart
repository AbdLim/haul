import 'package:download_engine/download_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/integration/quit_guard.dart';
import 'package:haul/services/system/app_window.dart';

import '../support/widget_host.dart';
import 'integration_support.dart';

void main() {
  late FakeAppWindow window;
  late StubDownloads downloads;
  final navigator = GlobalKey<NavigatorState>();
  var saved = 0;

  Future<void> boot(WidgetTester tester) async {
    saved = 0;
    window = FakeAppWindow();
    downloads = StubDownloads();
    QuitGuard(
      window: window,
      downloads: downloads,
      navigator: navigator,
      beforeQuit: () async => saved++,
    );
    await pumpHaul(tester, const SizedBox(), navigatorKey: navigator);
  }

  testWidgets('with nothing running it quits at once', (tester) async {
    await boot(tester);
    window.requestQuit();
    await tester.pump();
    expect(window.quitCalled, isTrue);
    expect(saved, 1);
  });

  testWidgets('with a download running it asks first, and can be refused', (
    tester,
  ) async {
    await boot(tester);
    downloads.set({'a': DownloadStatus.downloading});
    window.requestQuit();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Quit Haul?'), findsOneWidget);
    expect(find.textContaining('A download is still running'), findsOneWidget);
    await tester.tap(find.text('Keep downloading'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(window.quitCalled, isFalse);
  });

  testWidgets('agreeing saves progress and quits', (tester) async {
    await boot(tester);
    downloads.set({
      'a': DownloadStatus.downloading,
      'b': DownloadStatus.queued,
    });
    window.requestQuit();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.textContaining('2 downloads are still running'),
      findsOneWidget,
    );
    await tester.tap(find.text('Quit'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(saved, 1);
    expect(window.quitCalled, isTrue);
  });

  testWidgets('paused downloads do not hold up quitting', (tester) async {
    await boot(tester);
    downloads.set({'a': DownloadStatus.paused});
    window.requestQuit();
    await tester.pump();
    expect(window.quitCalled, isTrue);
  });
}
