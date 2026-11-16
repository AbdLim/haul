import 'package:download_engine/download_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/components/components.dart';
import 'package:haul/app/cubits/shell_cubit.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/data/site_rules_repository.dart';
import 'package:haul/features/settings/settings_pane.dart';
import 'package:haul/services/network/proxy_tester.dart';
import 'package:haul/services/system/secret_store.dart';

import '../support/app_harness.dart';
import '../support/test_deps.dart';
import '../support/widget_host.dart';

Future<void> open(WidgetTester tester, SettingsPane pane) async {
  cubit<ShellCubit>(tester).showSettings(pane: pane);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder iconButton(String tooltip) =>
    find.byWidgetPredicate((w) => w is HaulIconButton && w.tooltip == tooltip);

Finder field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is HaulTextField && w.semanticLabel == label,
  ),
  matching: find.byType(EditableText),
);

/// Lets chains of database and Keychain calls, started in the test's fake
/// time, run to the end.
Future<void> settle(WidgetTester tester, [int rounds = 10]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => realDelay(30));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  group('Connection', () {
    haulTest('the default connections are saved', (tester) async {
      final env = await boot(tester);
      await open(tester, SettingsPane.connection);
      await tester.tap(find.byType(HaulDropdown<int>).first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('16'));
      await settle(tester);
      expect(env.deps.settings.get(Keys.maxConnections), 16);
      await shutDown(tester, env);
    });

    haulTest('the speed limit is stored in bytes and sent to the engine', (
      tester,
    ) async {
      final env = await boot(tester);
      await open(tester, SettingsPane.connection);
      await tester.enterText(field('Speed limit'), '500');
      await tester.tap(find.byType(HaulToggle).first);
      await settle(tester);
      expect(env.deps.settings.get(Keys.speedLimitBytesPerSec), 500 * 1024);
      expect(env.deps.settings.get(Keys.speedLimitEnabled), isTrue);
      final limits = env.engine.commands.whereType<SetLimitsCommand>().last;
      expect(limits.speedLimitBytesPerSec, 500 * 1024);

      await tester.tap(find.text('KB/s'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('MB/s'));
      await settle(tester);
      expect(
        env.deps.settings.get(Keys.speedLimitBytesPerSec),
        500 * 1024 * 1024,
      );
      await shutDown(tester, env);
    });

    haulTest('a site can be given its own cap and lose it again', (
      tester,
    ) async {
      final env = await boot(tester);
      await open(tester, SettingsPane.connection);
      await tester.enterText(field('Site to limit'), ' Slow.Example.com ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      var rules = (await tester.runAsync(env.deps.siteRules.all))!;
      expect(rules.single.host, 'slow.example.com');
      expect(rules.single.maxConnections, 2);
      expect(find.text('slow.example.com'), findsOneWidget);
      final sent = env.engine.commands.whereType<SetNetworkCommand>().last;
      expect(sent.config.siteLimits, {'slow.example.com': 2});

      await tester.tap(iconButton('Remove slow.example.com'));
      await settle(tester);
      rules = (await tester.runAsync(env.deps.siteRules.all))!;
      expect(rules, isEmpty);
      await shutDown(tester, env);
    });

    haulTest('removing a cap keeps a never-take-over flag', (tester) async {
      final env = await boot(tester);
      await tester.runAsync(
        () => env.deps.siteRules.save(
          const SiteRule(
            host: 'a.com',
            maxConnections: 2,
            neverIntercept: true,
          ),
        ),
      );
      await open(tester, SettingsPane.connection);
      await settle(tester, 3);
      await tester.tap(iconButton('Remove a.com'));
      await settle(tester);
      final rules = (await tester.runAsync(env.deps.siteRules.all))!;
      expect(rules.single.maxConnections, isNull);
      expect(rules.single.neverIntercept, isTrue);
      await shutDown(tester, env);
    });
  });

  group('Proxy', () {
    haulTest('manual settings appear only for a manual proxy', (tester) async {
      final env = await boot(tester);
      await open(tester, SettingsPane.proxy);
      expect(find.text('Proxy host'), findsNothing);
      expect(find.text('Test proxy'), findsNothing);
      await tester.tap(find.text('Manual'));
      await settle(tester, 3);
      expect(find.text('Manual proxy'), findsOneWidget);
      expect(find.text('Test proxy'), findsOneWidget);
      await shutDown(tester, env);
    });

    haulTest('host, port and user are saved; the password goes to the '
        'Keychain only', (tester) async {
      final env = await boot(tester);
      await open(tester, SettingsPane.proxy);
      await tester.tap(find.text('Manual'));
      await settle(tester, 3);
      await tester.enterText(field('Proxy host'), 'proxy.local');
      await tester.enterText(field('Proxy port'), '3128');
      await tester.enterText(field('Proxy user name'), 'me');
      await tester.enterText(field('Proxy password'), 'hunter2');
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester);

      final s = env.deps.settings;
      expect(s.get(Keys.proxyHost), 'proxy.local');
      expect(s.get(Keys.proxyPort), 3128);
      expect(s.get(Keys.proxyUsername), 'me');
      final store = env.deps.secrets as MemorySecretStore;
      expect(store.values[proxyPasswordKey], 'hunter2');
      // The password is in no setting.
      for (final key in Keys.all) {
        expect(s.get(key).toString(), isNot(contains('hunter2')));
      }
      // The box hides what is typed.
      expect(
        tester.widget<EditableText>(field('Proxy password')).obscureText,
        isTrue,
      );

      final sent = env.engine.commands.whereType<SetNetworkCommand>().last;
      expect(sent.config.proxy!.host, 'proxy.local');
      expect(sent.config.proxy!.password, 'hunter2');
      await shutDown(tester, env);
    });

    haulTest('Test proxy reports what happened, in words', (tester) async {
      final env = await boot(tester);
      await tester.runAsync(() async {
        await env.deps.settings.set(Keys.proxyHost, 'p.local');
        await env.deps.settings.set(Keys.proxyPort, 8080);
        await env.deps.settings.set(Keys.proxyMode, ProxyMode.manual);
      });
      await open(tester, SettingsPane.proxy);
      await tester.tap(find.text('Test proxy'));
      await settle(tester, 4);
      expect(find.text('The proxy works'), findsOneWidget);
      final tester0 = env.deps.proxyTester! as FakeProxyTester;
      expect(tester0.tested.single.host, 'p.local');

      tester0.result = const ProxyTestResult.failed(
        'Could not connect through the proxy. Check the host and port',
      );
      await tester.tap(find.text('Test proxy'));
      await settle(tester, 4);
      expect(find.textContaining('Could not connect'), findsOneWidget);
      await shutDown(tester, env);
    });

    haulTest('Test proxy with nothing entered asks for a host first', (
      tester,
    ) async {
      final env = await boot(tester);
      await tester.runAsync(
        () => env.deps.settings.set(Keys.proxyMode, ProxyMode.manual),
      );
      await open(tester, SettingsPane.proxy);
      await tester.tap(find.text('Test proxy'));
      await settle(tester, 4);
      expect(find.text('Enter a host and a port first'), findsOneWidget);
      await shutDown(tester, env);
    });

    haulTest('the system proxy is shown as found', (tester) async {
      final env = await boot(tester);
      (env.deps.systemProxy! as FakeSystemProxy).proxy = const ProxyConfig(
        host: '10.0.0.5',
        port: 8080,
      );
      await tester.runAsync(
        () => env.deps.settings.set(Keys.proxyMode, ProxyMode.system),
      );
      await open(tester, SettingsPane.proxy);
      await settle(tester, 3);
      expect(find.text('10.0.0.5:8080'), findsOneWidget);
      await shutDown(tester, env);
    });

    haulTest('Reset this pane forgets the saved password too', (tester) async {
      final env = await boot(tester);
      final store = env.deps.secrets as MemorySecretStore;
      store.values[proxyPasswordKey] = 'x';
      await tester.runAsync(
        () => env.deps.settings.set(Keys.proxyMode, ProxyMode.system),
      );
      await open(tester, SettingsPane.proxy);
      await tester.tap(find.text('Reset this pane'));
      await settle(tester);
      expect(store.values, isNot(contains(proxyPasswordKey)));
      expect(env.deps.settings.get(Keys.proxyMode), ProxyMode.none);
      await shutDown(tester, env);
    });
  });

  group('Site logins', () {
    Future<void> fillDialog(
      WidgetTester tester, {
      String? host,
      String? user,
      String? password,
    }) async {
      if (host != null) await tester.enterText(field('Site'), host);
      if (user != null) await tester.enterText(field('User name'), user);
      if (password != null) {
        await tester.enterText(field('Password'), password);
      }
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.text('Save'));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));
    }

    haulTest('adding a login stores the password in the Keychain', (
      tester,
    ) async {
      final env = await boot(tester);
      await open(tester, SettingsPane.siteLogins);
      await tester.tap(find.text('Add login'));
      await tester.pump(const Duration(milliseconds: 300));
      await fillDialog(
        tester,
        host: 'https://Files.Example.com/x',
        user: 'ann',
        password: 'secret',
      );
      await save(tester);

      final logins = (await tester.runAsync(env.deps.siteLogins.all))!;
      expect(logins.single.host, 'files.example.com');
      expect(logins.single.username, 'ann');
      final store = env.deps.secrets as MemorySecretStore;
      expect(store.values[siteLoginKey('files.example.com')], 'secret');
      expect(find.text('files.example.com'), findsOneWidget);
      expect(find.text('ann'), findsOneWidget);
      expect(find.text('secret'), findsNothing);
      await shutDown(tester, env);
    });

    haulTest('an incomplete login says what is missing', (tester) async {
      final env = await boot(tester);
      await open(tester, SettingsPane.siteLogins);
      await tester.tap(find.text('Add login'));
      await tester.pump(const Duration(milliseconds: 300));
      await save(tester);
      expect(find.text('Enter the site, such as example.com'), findsOneWidget);
      await fillDialog(tester, host: 'a.com');
      await save(tester);
      expect(find.text('Enter a user name'), findsOneWidget);
      await fillDialog(tester, user: 'u');
      await save(tester);
      expect(find.text('Enter a password'), findsOneWidget);
      expect((await tester.runAsync(env.deps.siteLogins.all))!, isEmpty);
      await shutDown(tester, env);
    });

    haulTest('editing keeps the saved password unless a new one is typed', (
      tester,
    ) async {
      final env = await boot(tester);
      await tester.runAsync(
        () => env.deps.siteLogins.save('a.com', 'old', 'pw1'),
      );
      await open(tester, SettingsPane.siteLogins);
      await settle(tester, 3);
      await tester.tap(find.text('Edit'));
      await tester.pump(const Duration(milliseconds: 300));
      // The saved password is not put in the box.
      final pw = tester.widget<EditableText>(field('Password'));
      expect(pw.controller.text, isEmpty);
      expect(pw.obscureText, isTrue);

      await fillDialog(tester, user: 'new');
      await save(tester);
      var logins = (await tester.runAsync(env.deps.siteLogins.all))!;
      expect(logins.single.username, 'new');
      final store = env.deps.secrets as MemorySecretStore;
      expect(store.values[siteLoginKey('a.com')], 'pw1');

      await tester.tap(find.text('Edit'));
      await tester.pump(const Duration(milliseconds: 300));
      await fillDialog(tester, password: 'pw2');
      await save(tester);
      expect(store.values[siteLoginKey('a.com')], 'pw2');
      logins = (await tester.runAsync(env.deps.siteLogins.all))!;
      expect(logins.single.username, 'new');
      await shutDown(tester, env);
    });

    haulTest('deleting asks first, then removes the row and the password', (
      tester,
    ) async {
      final env = await boot(tester);
      await tester.runAsync(() => env.deps.siteLogins.save('a.com', 'u', 'pw'));
      await open(tester, SettingsPane.siteLogins);
      await settle(tester, 3);
      await tester.tap(iconButton('Delete the login for a.com'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Delete this login?'), findsOneWidget);
      await tester.tap(find.text('Keep'));
      await tester.pump(const Duration(milliseconds: 300));
      expect((await tester.runAsync(env.deps.siteLogins.all))!, hasLength(1));

      await tester.tap(iconButton('Delete the login for a.com'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect((await tester.runAsync(env.deps.siteLogins.all))!, isEmpty);
      final store = env.deps.secrets as MemorySecretStore;
      expect(store.values, isNot(contains(siteLoginKey('a.com'))));
      await shutDown(tester, env);
    });
  });
}
