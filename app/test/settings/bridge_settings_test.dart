import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/cubits/browser_status_cubit.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/features/settings/settings_pane.dart';

import '../support/app_harness.dart';
import '../support/widget_host.dart';

void main() {
  haulTest('a taken port is shown in Settings and the app still runs', (
    tester,
  ) async {
    final blocker = (await tester.runAsync(
      () => ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    ))!;
    final env = await boot(tester, bridgePort: blocker.port);
    await tester.runAsync(() => env.deps.bridge!.start());
    cubit<ShellCubit>(tester).showSettings(pane: SettingsPane.general);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('is in use by another app'), findsOneWidget);
    await tester.runAsync(blocker.close);
    await shutDown(tester, env);
  });

  haulTest('only an allowed port is saved from the Port box', (tester) async {
    final env = await boot(tester);
    cubit<ShellCubit>(tester).showSettings(pane: SettingsPane.general);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final box = find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is HaulTextField && w.semanticLabel == 'Bridge port',
      ),
      matching: find.byType(EditableText),
    );
    await tester.enterText(box, '80');
    await tester.pump();
    expect(env.deps.settings.get(Keys.bridgePort), 47821);
    await tester.enterText(box, '50123');
    await tester.pump();
    expect(env.deps.settings.get(Keys.bridgePort), 50123);
    await tester.enterText(box, '70000');
    await tester.pump();
    expect(env.deps.settings.get(Keys.bridgePort), 50123);
    await shutDown(tester, env);
  });

  haulTest('a browser that proves its token marks Haul as connected', (
    tester,
  ) async {
    final env = await boot(tester, bridgePort: 0);
    await tester.runAsync(() => env.deps.bridge!.start());
    expect(cubit<BrowserStatusCubit>(tester).state, BrowserStatus.notPaired);
    env.deps.bridge!.onAuthenticated!();
    await tester.pump();
    expect(cubit<BrowserStatusCubit>(tester).state, BrowserStatus.connected);
    // Silence for a few minutes means it has gone.
    await tester.pump(const Duration(minutes: 4));
    expect(cubit<BrowserStatusCubit>(tester).state, BrowserStatus.notPaired);
    await shutDown(tester, env);
  });
}
