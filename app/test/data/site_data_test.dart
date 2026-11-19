import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/data/database.dart';
import 'package:haul/data/site_logins_repository.dart';
import 'package:haul/data/site_rules_repository.dart';
import 'package:haul/services/system/secret_store.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late HaulDatabase db;
  setUp(() => db = HaulDatabase.inMemory());
  tearDown(() => db.close());

  group('site rules', () {
    late SiteRulesRepository rules;
    setUp(() => rules = SiteRulesRepository(db));

    test('save, read, update and delete', () async {
      await rules.save(
        const SiteRule(host: 'CDN.Example.com', maxConnections: 2),
      );
      var all = await rules.all();
      expect(all.single.host, 'cdn.example.com');
      expect(all.single.maxConnections, 2);

      await rules.save(
        const SiteRule(host: 'cdn.example.com', maxConnections: 4),
      );
      all = await rules.all();
      expect(all, hasLength(1));
      expect(all.single.maxConnections, 4);

      await rules.delete(' CDN.example.com ');
      expect(await rules.all(), isEmpty);
    });

    test('a rule with nothing in it is not kept', () async {
      await rules.save(const SiteRule(host: 'a.com', maxConnections: 2));
      await rules.save(const SiteRule(host: 'a.com'));
      expect(await rules.all(), isEmpty);
    });

    test('feeds the engine and the extension', () async {
      await rules.save(const SiteRule(host: 'a.com', maxConnections: 2));
      await rules.save(const SiteRule(host: 'b.com', neverIntercept: true));
      await rules.save(
        const SiteRule(host: 'c.com', maxConnections: 1, neverIntercept: true),
      );
      expect(await rules.connectionLimits(), {'a.com': 2, 'c.com': 1});
      expect(await rules.excludedHosts(), ['b.com', 'c.com']);
    });

    test('an empty host is refused', () async {
      expect(() => rules.save(const SiteRule(host: ' ')), throwsArgumentError);
    });

    test('watchAll follows changes', () async {
      final seen = <int>[];
      final sub = rules.watchAll().listen((l) => seen.add(l.length));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await rules.save(const SiteRule(host: 'a.com', maxConnections: 2));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await sub.cancel();
      expect(seen.first, 0);
      expect(seen.last, 1);
    });
  });

  group('site logins', () {
    late MemorySecretStore secrets;
    late SiteLoginsRepository logins;
    setUp(() {
      secrets = MemorySecretStore();
      logins = SiteLoginsRepository(db, secrets);
    });

    test(
      'the password is in the secret store and nowhere in the database',
      () async {
        await logins.save('Files.Example.com', 'alice', 'S3cret-pw!');

        expect(secrets.values['haul.login.files.example.com'], 'S3cret-pw!');
        final rows = await db.select(db.siteLogins).get();
        expect(rows.single.host, 'files.example.com');
        expect(rows.single.username, 'alice');

        // Search every table for the password text.
        final dump = StringBuffer();
        for (final t in [
          'site_logins',
          'settings',
          'downloads',
          'site_rules',
        ]) {
          for (final r in await db.customSelect('SELECT * FROM $t').get()) {
            dump.write(r.data.values.join('|'));
          }
        }
        expect(dump.toString().contains('S3cret-pw!'), isFalse);
      },
    );

    test('the list never carries passwords', () async {
      await logins.save('a.com', 'u', 'pw');
      final e = (await logins.all()).single;
      expect(e.host, 'a.com');
      expect(e.username, 'u');
    });

    test('deleting a login removes its Keychain entry', () async {
      await logins.save('a.com', 'u', 'pw');
      await logins.save('b.com', 'v', 'pw2');
      await logins.delete('A.com');

      expect(secrets.values.containsKey('haul.login.a.com'), isFalse);
      expect(secrets.values['haul.login.b.com'], 'pw2');
      expect((await logins.all()).map((e) => e.host), ['b.com']);
    });

    test('saving again replaces the login and its password', () async {
      await logins.save('a.com', 'old', 'oldpw');
      await logins.save('a.com', 'new', 'newpw');
      expect(await logins.all(), hasLength(1));
      expect((await logins.all()).single.username, 'new');
      expect(await logins.password('a.com'), 'newpw');
    });

    test('rename keeps the password', () async {
      await logins.save('a.com', 'old', 'pw');
      await logins.rename('a.com', 'renamed');
      expect((await logins.all()).single.username, 'renamed');
      expect(await logins.password('a.com'), 'pw');
    });

    test(
      'forEngine returns host to login, skipping rows with no password',
      () async {
        await logins.save('a.com', 'u', 'pw');
        await logins.save('b.com', 'v', 'pw2');
        secrets.values.remove('haul.login.b.com'); // lost from the Keychain

        final map = await logins.forEngine();
        expect(map.keys, ['a.com']);
        expect(map['a.com']!.username, 'u');
        expect(map['a.com']!.password, 'pw');
      },
    );

    test('an empty host is refused', () async {
      expect(() => logins.save('', 'u', 'p'), throwsArgumentError);
      expect(secrets.values, isEmpty);
    });
  });

  test('the proxy password key is fixed', () {
    expect(proxyPasswordKey, 'haul.proxy');
    expect(siteLoginKey('X.com'), 'haul.login.x.com');
  });
}
