import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/theme/haul_theme.dart';
import 'package:haul/data/setting_keys.dart';

/// Puts [child] in a real `WidgetsApp` (so there is a Navigator and an
/// Overlay for menus and dialogs) under Haul's theme, aligned top-left.
Future<void> pumpHaul(
  WidgetTester tester,
  Widget child, {
  AppThemeMode mode = AppThemeMode.dark,
  Size size = const Size(800, 600),
  bool reduceMotion = false,
  Alignment alignment = Alignment.topLeft,
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    WidgetsApp(
      navigatorKey: navigatorKey,
      color: const Color(0xFF000000),
      debugShowCheckedModeBanner: false,
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, _) => builder(context),
      ),
      builder: (context, navigator) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: HaulThemeScope(
          mode: mode,
          duration: Duration.zero,
          child: navigator!,
        ),
      ),
      home: ColoredBox(
        color: mode == AppThemeMode.dark
            ? HaulTheme.dark.colors.bgWindow
            : HaulTheme.light.colors.bgWindow,
        child: Align(
          alignment: alignment,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// A mouse pointer, for hover tests.
Future<TestGesture> mouse(WidgetTester tester) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: const Offset(-100, -100));
  addTearDown(g.removePointer);
  return g;
}

/// A widget test that runs as macOS, which is what Haul is. Hover and focus
/// highlights follow the desktop rules there, and the system menus exist.
void haulTest(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  Object? skip,
}) {
  testWidgets(
    description,
    body,
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    skip: skip == true || skip is String,
  );
}
