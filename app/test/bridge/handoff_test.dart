import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/features/add_download/add_download_dialog.dart';
import 'package:haul/services/bridge/bridge_payload.dart';
import 'package:haul/services/system/app_window.dart';

import '../support/app_harness.dart';
import '../support/test_deps.dart';
import '../support/widget_host.dart';

BridgePayload payload({String name = 'file.zip'}) => BridgePayload(
  url: Uri.parse('https://example.com/$name'),
  source: 'chrome',
  fileName: name,
  referrer: 'https://example.com/downloads',
  userAgent: 'Mozilla/5.0 test',
  cookies: 'session=abc',
  fileSize: 5 * 1024 * 1024,
);

Future<String> send(WidgetTester tester, Env env, BridgePayload p) async {
  final id = (await tester.runAsync(() => env.deps.intake!.accept(p)))!;
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return id;
}

/// A text box holding exactly [text].
Finder fieldWith(String text) => find.byWidgetPredicate(
  (w) => w is EditableText && w.controller.text == text,
);

void main() {
  haulTest('the app comes forward with the dialog filled in', (tester) async {
    final env = await boot(tester);
    final window = env.deps.window! as FakeAppWindow..visible = false;
    await send(tester, env, payload());
    expect(window.visible, isTrue);
    expect(find.byType(AddDownloadDialog), findsOneWidget);
    expect(find.text('Sent by Chrome'), findsOneWidget);
    expect(fieldWith('https://example.com/file.zip'), findsOneWidget);
    expect(fieldWith('file.zip'), findsOneWidget);
    await shutDown(tester, env);
  });

  haulTest('the link is looked at with the browser\'s headers', (tester) async {
    final env = await boot(tester);
    await send(tester, env, payload());
    await tester.runAsync(() => realDelay(600));
    await tester.pump();
    final prober = env.deps.urlProber as FakeUrlProber;
    expect(prober.headers.single.cookies, 'session=abc');
    expect(prober.headers.single.referrer, 'https://example.com/downloads');
    expect(prober.headers.single.userAgent, 'Mozilla/5.0 test');
    await shutDown(tester, env);
  });

  haulTest('Start stores it with the headers, under the id the browser got', (
    tester,
  ) async {
    final env = await boot(tester);
    final id = await send(tester, env, payload());
    expect(await tester.runAsync(env.deps.downloads.downloads), isEmpty);
    await tester.tap(find.text('Start'));
    await tester.runAsync(() => realDelay());
    await tester.pump(const Duration(milliseconds: 300));
    final stored = (await tester.runAsync(env.deps.downloads.downloads))!
        .single;
    expect(stored.id, id);
    expect(stored.source, 'chrome');
    final req = stored.snapshot.request;
    expect(req.cookies, 'session=abc');
    expect(req.referrer, 'https://example.com/downloads');
    expect(req.userAgent, 'Mozilla/5.0 test');
    expect(req.fileName, 'file.zip');
    await shutDown(tester, env);
  });

  haulTest('Cancel stores nothing', (tester) async {
    final env = await boot(tester);
    await send(tester, env, payload());
    await tester.tap(find.text('Cancel'));
    await tester.runAsync(() => realDelay());
    await tester.pumpAndSettle();
    expect(await tester.runAsync(env.deps.downloads.downloads), isEmpty);
    expect(cubit<ShellCubit>(tester).state.addDialogOpen, isFalse);
    expect(find.byType(AddDownloadDialog), findsNothing);
    await shutDown(tester, env);
  });

  haulTest('with start-at-once on there is no dialog', (tester) async {
    final env = await boot(tester);
    await tester.runAsync(
      () => env.deps.settings.set(Keys.autoStartBrowserDownloads, true),
    );
    await send(tester, env, payload());
    await tester.runAsync(() => realDelay());
    expect(find.byType(AddDownloadDialog), findsNothing);
    final stored = (await tester.runAsync(env.deps.downloads.downloads))!
        .single;
    expect(stored.source, 'chrome');
    expect(stored.snapshot.request.cookies, 'session=abc');
    await shutDown(tester, env);
  });

  haulTest('a second one while the dialog is open joins the queue', (
    tester,
  ) async {
    final env = await boot(tester);
    await send(tester, env, payload(name: 'first.zip'));
    await send(tester, env, payload(name: 'second.zip'));
    // The dialog still shows the first; the second was added quietly.
    expect(fieldWith('first.zip'), findsOneWidget);
    final stored = (await tester.runAsync(env.deps.downloads.downloads))!;
    expect(stored.map((d) => d.snapshot.request.fileName), ['second.zip']);
    await shutDown(tester, env);
  });
}
