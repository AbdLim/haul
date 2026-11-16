import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/data/database.dart';
import 'package:haul/data/downloads_repository.dart';
import 'package:haul/data/network_sync.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/data/settings_repository.dart';
import 'package:haul/data/site_logins_repository.dart';
import 'package:haul/data/site_rules_repository.dart';
import 'package:haul/services/system/secret_store.dart';

import '../../../packages/download_engine/test_support/range_server.dart';
import '../../../packages/download_engine/test_support/test_proxy.dart';

const mib = 1024 * 1024;

/// The whole path, with the real engine: settings and the Keychain in, a
/// request that goes out the other end.
void main() {
  late Directory dir;
  late HaulDatabase db;
  late SettingsRepository settings;
  late MemorySecretStore secrets;
  late SiteLoginsRepository logins;
  late SiteRulesRepository rules;
  late IsolateEngine engine;
  late DownloadsRepository repo;
  late NetworkSync sync;
  late RangeServer server;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    dir = Directory.systemTemp.createTempSync('netsync_');
    db = HaulDatabase.inMemory();
    settings = await SettingsRepository.open(db);
    secrets = MemorySecretStore();
    logins = SiteLoginsRepository(db, secrets);
    rules = SiteRulesRepository(db);
    engine = await IsolateEngine.start();
    repo = DownloadsRepository(engine: engine, database: db);
    sync = NetworkSync(
      settings: settings,
      secrets: secrets,
      logins: logins,
      rules: rules,
      downloads: repo,
      delay: const Duration(milliseconds: 20),
    );
    server = await RangeServer.start(size: 1 * mib);
  });

  tearDown(() async {
    await sync.dispose();
    await repo.dispose();
    await server.close();
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<DownloadSnapshot> finish(String id) async {
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(end)) {
      final d = await db.downloadsDao.byId(id);
      final s = d?.snapshot.status;
      if (s == DownloadStatus.completed || s == DownloadStatus.failed) {
        return d!.snapshot;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    fail('$id did not finish');
  }

  DownloadRequest request(String id) => DownloadRequest(
    id: id,
    url: server.url,
    saveDir: dir.path,
    maxConnections: 2,
  );

  test('a download goes through the proxy set in the settings', () async {
    final proxy = await TestProxy.start();
    addTearDown(proxy.close);
    await settings.set(Keys.proxyHost, '127.0.0.1');
    await settings.set(Keys.proxyPort, proxy.port);
    await settings.set(Keys.proxyMode, ProxyMode.manual);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    await repo.add(request('p'));
    final done = await finish('p');
    expect(done.status, DownloadStatus.completed);
    expect(proxy.log, isNotEmpty);
    expect(server.log.length, proxy.log.length);
  });

  test('with the proxy off, nothing goes through it', () async {
    final proxy = await TestProxy.start();
    addTearDown(proxy.close);
    await settings.set(Keys.proxyHost, '127.0.0.1');
    await settings.set(Keys.proxyPort, proxy.port);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await repo.add(request('n'));
    expect((await finish('n')).status, DownloadStatus.completed);
    expect(proxy.log, isEmpty);
  });

  test('a saved site login is sent to its host', () async {
    server.basicAuthUser = 'ann';
    server.basicAuthPassword = 'secret';
    await logins.save('127.0.0.1', 'ann', 'secret');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await repo.add(request('a'));
    expect((await finish('a')).status, DownloadStatus.completed);
  });

  test('without the login the download says a login is needed', () async {
    server.basicAuthUser = 'ann';
    server.basicAuthPassword = 'secret';
    await repo.add(request('b'));
    final s = await finish('b');
    expect(s.status, DownloadStatus.failed);
    expect(s.error?.code, DownloadErrorCode.authRequired);
  });
}
