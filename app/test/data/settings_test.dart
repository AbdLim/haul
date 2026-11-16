import 'dart:async';
import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/data/database.dart';
import 'package:haul/data/downloads_repository.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/data/settings_engine_sync.dart';
import 'package:haul/data/settings_repository.dart';

class RecordingEngine implements EngineApi {
  final commands = <EngineCommand>[];
  @override
  Stream<EngineEvent> get events => const Stream.empty();
  @override
  void send(EngineCommand c) => commands.add(c);
  @override
  Future<void> dispose() async {}
  List<SetLimitsCommand> get limits =>
      commands.whereType<SetLimitsCommand>().toList();
}

Future<void> settle([int ms = 30]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late HaulDatabase db;
  late SettingsRepository settings;

  setUp(() async {
    db = HaulDatabase.inMemory();
    settings = await SettingsRepository.open(db);
  });
  tearDown(() async {
    await settings.dispose();
    await db.close();
  });

  group('defaults', () {
    test('an empty database gives the default values', () {
      expect(settings.get(Keys.maxConnections), 8);
      expect(settings.get(Keys.maxConcurrentDownloads), 3);
      expect(settings.get(Keys.speedLimitBytesPerSec), 0);
      expect(settings.get(Keys.speedLimitEnabled), isFalse);
      expect(settings.get(Keys.autoStartBrowserDownloads), isFalse);
      expect(settings.get(Keys.resumeOnLaunch), isTrue);
      expect(settings.get(Keys.bridgePort), 47821);
      expect(settings.get(Keys.bridgeToken), isNull);
      expect(settings.get(Keys.launchAtLogin), isFalse);
      expect(settings.get(Keys.notificationsEnabled), isTrue);
      expect(settings.get(Keys.themeMode), AppThemeMode.system);
      expect(settings.get(Keys.startHidden), isFalse);
      expect(settings.get(Keys.keepAwake), isTrue);
      expect(settings.get(Keys.browserIntegrationEnabled), isTrue);
      expect(settings.get(Keys.interceptMinBytes), 1048576);
      expect(settings.get(Keys.rememberLastFolderPerCategory), isFalse);
      expect(settings.get(Keys.duplicateAction), DuplicateAction.ask);
      expect(settings.get(Keys.autoRemoveCompleted), AutoRemove.never);
      expect(settings.get(Keys.retryAttempts), 8);
      expect(settings.get(Keys.stallTimeoutSeconds), 30);
      expect(settings.get(Keys.proxyMode), ProxyMode.none);
      expect(settings.get(Keys.notifyOnComplete), isTrue);
      expect(settings.get(Keys.notifyOnFailure), isTrue);
      expect(settings.get(Keys.listDensity), ListDensity.comfortable);
      expect(settings.get(Keys.showSpeedInMenuBar), isTrue);
    });

    test('the default intercept list is the standard list', () {
      expect(
        settings.get(Keys.interceptExtensions),
        'zip rar 7z tar gz dmg pkg iso exe msi apk mp4 mkv mov avi mp3 flac wav pdf epub'
            .split(' '),
      );
    });

    test('every key has a unique name', () {
      final names = Keys.all.map((k) => k.name).toList();
      expect(names.toSet(), hasLength(names.length));
      expect(names.length, 37);
    });
  });

  group('reading and writing', () {
    test('values of every shape round trip', () async {
      await settings.set(Keys.maxConnections, 16);
      await settings.set(Keys.launchAtLogin, true);
      await settings.set(Keys.defaultSaveDir, '/Users/me/Stuff');
      await settings.set(Keys.proxyPort, 8080);
      await settings.set(Keys.proxyBypass, ['a.com', '*.b.org']);
      await settings.set(Keys.themeMode, AppThemeMode.dark);
      await settings.set(Keys.duplicateAction, DuplicateAction.resumeExisting);

      expect(settings.get(Keys.maxConnections), 16);
      expect(settings.get(Keys.launchAtLogin), isTrue);
      expect(settings.get(Keys.defaultSaveDir), '/Users/me/Stuff');
      expect(settings.get(Keys.proxyPort), 8080);
      expect(settings.get(Keys.proxyBypass), ['a.com', '*.b.org']);
      expect(settings.get(Keys.themeMode), AppThemeMode.dark);
      expect(
        settings.get(Keys.duplicateAction),
        DuplicateAction.resumeExisting,
      );
    });

    test('an optional value can be set back to null', () async {
      await settings.set(Keys.defaultSaveDir, '/x');
      await settings.set(Keys.defaultSaveDir, null);
      expect(settings.get(Keys.defaultSaveDir), isNull);
    });

    test('a corrupt or unknown stored value reads as the default', () async {
      await db
          .into(db.settings)
          .insert(
            SettingsCompanion.insert(
              key: 'maxConnections',
              value: '"not a number"',
            ),
          );
      await db
          .into(db.settings)
          .insert(SettingsCompanion.insert(key: 'themeMode', value: '"neon"'));
      await db
          .into(db.settings)
          .insert(
            SettingsCompanion.insert(key: 'launchAtLogin', value: '{broken'),
          );
      final s = await SettingsRepository.open(db);
      expect(s.get(Keys.maxConnections), 8);
      expect(s.get(Keys.themeMode), AppThemeMode.system);
      expect(s.get(Keys.launchAtLogin), isFalse);
      await s.dispose();
    });
  });

  group('persistence', () {
    test('values survive closing and reopening the database', () async {
      final dir = Directory.systemTemp.createTempSync('settings_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/haul.sqlite');

      final first = HaulDatabase.file(file);
      final s1 = await SettingsRepository.open(first);
      await s1.set(Keys.maxConcurrentDownloads, 5);
      await s1.set(Keys.themeMode, AppThemeMode.light);
      await s1.set(Keys.interceptExtensions, ['zip', 'iso']);
      await s1.dispose();
      await first.close();

      final second = HaulDatabase.file(file);
      final s2 = await SettingsRepository.open(second);
      expect(s2.get(Keys.maxConcurrentDownloads), 5);
      expect(s2.get(Keys.themeMode), AppThemeMode.light);
      expect(s2.get(Keys.interceptExtensions), ['zip', 'iso']);
      expect(s2.get(Keys.maxConnections), 8); // never changed
      await s2.dispose();
      await second.close();
    });
  });

  group('streams', () {
    test('watch emits the current value, then each change', () async {
      await settings.set(Keys.maxConnections, 4);
      final seen = <int>[];
      final sub = settings.watch(Keys.maxConnections).listen(seen.add);
      await settle();
      await settings.set(Keys.maxConnections, 2);
      await settings.set(Keys.maxConnections, 16);
      await settle();
      await sub.cancel();
      expect(seen, [4, 2, 16]);
    });

    test('setting the same value does not emit', () async {
      final seen = <bool>[];
      final sub = settings.watch(Keys.launchAtLogin).listen(seen.add);
      await settle();
      await settings.set(Keys.launchAtLogin, false);
      await settings.set(Keys.launchAtLogin, false);
      await settle();
      await sub.cancel();
      expect(seen, [false]);
    });

    test('keys are independent', () async {
      final seen = <int>[];
      final sub = settings.watch(Keys.maxConnections).listen(seen.add);
      await settle();
      await settings.set(Keys.maxConcurrentDownloads, 9);
      await settle();
      await sub.cancel();
      expect(seen, [8]);
    });

    test('two listeners both get changes', () async {
      final a = <int>[];
      final b = <int>[];
      final s1 = settings.watch(Keys.bridgePort).listen(a.add);
      final s2 = settings.watch(Keys.bridgePort).listen(b.add);
      await settle();
      await settings.set(Keys.bridgePort, 50000);
      await settle();
      await s1.cancel();
      await s2.cancel();
      expect(a, [47821, 50000]);
      expect(b, [47821, 50000]);
    });
  });

  group('reset', () {
    test('puts only the given keys back to their defaults', () async {
      await settings.set(Keys.maxConnections, 2);
      await settings.set(Keys.maxConcurrentDownloads, 7);
      final seen = <int>[];
      final sub = settings.watch(Keys.maxConnections).listen(seen.add);
      await settle();

      await settings.reset([Keys.maxConnections]);
      await settle();
      await sub.cancel();

      expect(settings.get(Keys.maxConnections), 8);
      expect(settings.get(Keys.maxConcurrentDownloads), 7);
      expect(seen, [2, 8]);
      expect(await db.select(db.settings).get(), hasLength(1));
    });

    test('resetting everything leaves an empty table', () async {
      await settings.set(Keys.maxConnections, 2);
      await settings.set(Keys.themeMode, AppThemeMode.dark);
      await settings.reset(Keys.all);
      expect(await db.select(db.settings).get(), isEmpty);
      expect(settings.get(Keys.themeMode), AppThemeMode.system);
    });
  });

  group('engine sync', () {
    late RecordingEngine engine;
    late DownloadsRepository downloads;
    late SettingsEngineSync sync;

    setUp(() {
      engine = RecordingEngine();
      downloads = DownloadsRepository(engine: engine, database: db);
      sync = SettingsEngineSync(settings, downloads);
    });
    tearDown(() async {
      await sync.dispose();
      await downloads.dispose();
    });

    test('the current limits are pushed at start', () {
      final c = engine.limits.single;
      expect(c.maxConcurrentDownloads, 3);
      expect(c.maxConnections, 8);
      expect(c.speedLimitBytesPerSec, 0);
    });

    test('a change sends setLimits with the new values', () async {
      await settings.set(Keys.maxConcurrentDownloads, 1);
      await settle();
      expect(engine.limits.last.maxConcurrentDownloads, 1);

      await settings.set(Keys.maxConnections, 16);
      await settle();
      expect(engine.limits.last.maxConnections, 16);
    });

    test('the speed limit applies only while its switch is on', () async {
      await settings.set(Keys.speedLimitBytesPerSec, 2 * 1024 * 1024);
      await settle();
      expect(
        engine.limits.last.speedLimitBytesPerSec,
        0,
        reason: 'switch is off',
      );

      await settings.set(Keys.speedLimitEnabled, true);
      await settle();
      expect(engine.limits.last.speedLimitBytesPerSec, 2 * 1024 * 1024);

      await settings.set(Keys.speedLimitEnabled, false);
      await settle();
      expect(engine.limits.last.speedLimitBytesPerSec, 0);
    });

    test('unrelated settings send nothing', () async {
      final before = engine.limits.length;
      await settings.set(Keys.themeMode, AppThemeMode.dark);
      await settings.set(Keys.launchAtLogin, true);
      await settle();
      expect(engine.limits.length, before);
    });
  });
}
