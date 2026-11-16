import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/app/theme/haul_theme.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/features/shell/shell_metrics.dart';
import 'package:haul/features/shell/shell_page.dart';
import 'package:haul/services/system/window_chrome.dart';

Widget host(ShellCubit shell, NoWindowChrome chrome, {Widget? detail}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1200, 800)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: BlocProvider.value(
        value: shell,
        child: HaulThemeScope(
          mode: AppThemeMode.dark,
          child: ShellPage(
            chrome: chrome,
            native: false,
            sidebar: const Text('SIDEBAR'),
            // Like the real header, its plain content ignores clicks so they
            // reach the drag and zoom layer behind it.
            header: const IgnorePointer(child: Text('HEADER')),
            content: const Text('LIST'),
            detail: detail,
            settings: const Text('SETTINGS'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late ShellCubit shell;
  late NoWindowChrome chrome;
  setUp(() {
    shell = ShellCubit();
    chrome = NoWindowChrome();
  });
  tearDown(() => shell.close());

  testWidgets('three regions: a 220 sidebar, a 120 header, the list below', (
    tester,
  ) async {
    await tester.pumpWidget(host(shell, chrome));

    expect(tester.getSize(find.text('SIDEBAR')).width, lessThanOrEqualTo(220));
    final sidebarBox = tester.getRect(
      find
          .ancestor(of: find.text('SIDEBAR'), matching: find.byType(SizedBox))
          .first,
    );
    expect(sidebarBox.width, ShellMetrics.sidebarWidth);

    final header = tester.getTopLeft(find.text('HEADER'));
    final list = tester.getTopLeft(find.text('LIST'));
    expect(list.dy - header.dy, closeTo(ShellMetrics.headerHeight, 20));
    expect(header.dx, greaterThanOrEqualTo(ShellMetrics.sidebarWidth));
  });

  testWidgets('the header band is exactly 120 tall', (tester) async {
    await tester.pumpWidget(host(shell, chrome));
    final box = tester.getRect(
      find
          .ancestor(of: find.text('HEADER'), matching: find.byType(SizedBox))
          .first,
    );
    expect(box.height, ShellMetrics.headerHeight);
  });

  testWidgets('double-clicking the header zooms the window', (tester) async {
    await tester.pumpWidget(host(shell, chrome));
    await tester.tap(find.text('HEADER'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('HEADER'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(chrome.zoomToggles, 1);
  });

  testWidgets('a single click on the header does not zoom', (tester) async {
    await tester.pumpWidget(host(shell, chrome));
    await tester.tap(find.text('HEADER'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(chrome.zoomToggles, 0);
  });

  testWidgets('Settings replaces the header and the list, the sidebar stays', (
    tester,
  ) async {
    await tester.pumpWidget(host(shell, chrome));
    expect(find.text('LIST'), findsOneWidget);
    expect(find.text('SETTINGS'), findsNothing);

    shell.showSettings();
    await tester.pump();
    // The old view fades out over 220 ms.
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('LIST'), findsNothing);
    expect(find.text('HEADER'), findsNothing);
    expect(find.text('SIDEBAR'), findsOneWidget);

    shell.showDownloads();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('a detail panel sits to the right of the list', (tester) async {
    await tester.pumpWidget(host(shell, chrome, detail: const Text('DETAIL')));
    expect(
      tester.getTopLeft(find.text('DETAIL')).dx,
      greaterThan(tester.getTopLeft(find.text('LIST')).dx),
    );
  });

  test('the layout constants are the design numbers', () {
    expect(ShellMetrics.sidebarWidth, 220);
    expect(ShellMetrics.headerHeight, 120);
    expect(ShellMetrics.detailWidth, 340);
    expect(ShellMetrics.rowHeight, 64);
    expect(minimumWindowSize, const Size(960, 600));
  });
}
