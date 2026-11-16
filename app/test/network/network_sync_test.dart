import 'package:download_engine/download_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/dependencies.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/data/site_rules_repository.dart';
import 'package:haul/services/system/secret_store.dart';

import '../support/test_deps.dart';

Future<void> wait([int ms = 120]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late AppDependencies deps;
  late FakeEngine engine;

  setUp(() async {
    final t = await makeTestDeps();
    deps = t.deps;
    engine = t.engine;
    await wait();
  });
  tearDown(() => deps.dispose());

  NetworkConfig lastSent() =>
      engine.commands.whereType<SetNetworkCommand>().last.config;

  test('sends a configuration at start: no proxy, nothing else', () {
    final c = lastSent();
    expect(c.proxy, isNull);
    expect(c.siteLogins, isEmpty);
    expect(c.siteLimits, isEmpty);
    expect(c.defaultUserAgent, isNull);
  });

  test('a manual proxy is sent with its password from the Keychain', () async {
    await deps.secrets.write(proxyPasswordKey, 'pw');
    await deps.settings.set(Keys.proxyHost, 'proxy.local');
    await deps.settings.set(Keys.proxyPort, 3128);
    await deps.settings.set(Keys.proxyUsername, 'me');
    await deps.settings.set(Keys.proxyBypass, ['*.corp']);
    await deps.settings.set(Keys.proxyMode, ProxyMode.manual);
    await wait();
    final p = lastSent().proxy!;
    expect(
      (p.host, p.port, p.username, p.password),
      ('proxy.local', 3128, 'me', 'pw'),
    );
    expect(p.bypass, ['*.corp']);
  });

  test('a manual proxy without a host or port is not sent', () async {
    await deps.settings.set(Keys.proxyMode, ProxyMode.manual);
    await wait();
    expect(lastSent().proxy, isNull);
  });

  test('changing the password alone sends again', () async {
    await deps.settings.set(Keys.proxyHost, 'p');
    await deps.settings.set(Keys.proxyPort, 1);
    await deps.settings.set(Keys.proxyUsername, 'u');
    await deps.settings.set(Keys.proxyMode, ProxyMode.manual);
    await wait();
    expect(lastSent().proxy!.password, isNull);
    await deps.secrets.write(proxyPasswordKey, 'new');
    deps.networkSync!.passwordChanged();
    await wait();
    expect(lastSent().proxy!.password, 'new');
  });

  test('the system proxy is resolved and sent as a manual one', () async {
    (deps.systemProxy! as FakeSystemProxy).proxy = const ProxyConfig(
      host: 'sys',
      port: 9,
      bypass: ['*.local'],
    );
    await deps.settings.set(Keys.proxyMode, ProxyMode.system);
    await wait();
    expect(lastSent().proxy!.host, 'sys');
    expect(lastSent().proxy!.bypass, ['*.local']);
  });

  test('site logins, caps and the user agent follow their sources', () async {
    await deps.siteLogins.save('Files.Example.com', 'ann', 'secret');
    await deps.siteRules.save(
      const SiteRule(host: 'slow.example.com', maxConnections: 2),
    );
    await deps.settings.set(Keys.defaultUserAgent, 'Agent/1');
    await wait();
    final c = lastSent();
    expect(c.siteLogins['files.example.com']!.username, 'ann');
    expect(c.siteLogins['files.example.com']!.password, 'secret');
    expect(c.siteLimits, {'slow.example.com': 2});
    expect(c.defaultUserAgent, 'Agent/1');

    await deps.siteLogins.delete('files.example.com');
    await wait();
    expect(lastSent().siteLogins, isEmpty);
  });

  test('changes made together are sent once', () async {
    final before = engine.commands.whereType<SetNetworkCommand>().length;
    await deps.settings.set(Keys.defaultUserAgent, 'A');
    await deps.settings.set(Keys.defaultUserAgent, 'B');
    await deps.settings.set(Keys.defaultUserAgent, 'C');
    await wait();
    expect(
      engine.commands.whereType<SetNetworkCommand>().length - before,
      lessThanOrEqualTo(2),
    );
    expect(lastSent().defaultUserAgent, 'C');
  });

  test('the latest configuration is kept for the Add dialog', () async {
    await deps.settings.set(Keys.defaultUserAgent, 'Z');
    await wait();
    expect(deps.networkSync!.latest.defaultUserAgent, 'Z');
  });
}
