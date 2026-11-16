import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/integration/power_coordinator.dart';
import 'package:haul/app/integration/tray_coordinator.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/data/settings_repository.dart';
import 'package:haul/services/system/login_item.dart';
import 'package:haul/services/system/sleep_blocker.dart';
import 'package:haul/services/system/tray_host.dart';

import 'integration_support.dart';

void main() {
  group('menu bar menu', () {
    late StubThroughput throughput;
    late FakeTrayHost host;
    late TrayCoordinator tray;
    final log = <String>[];

    setUp(() async {
      log.clear();
      throughput = StubThroughput();
      host = FakeTrayHost();
      tray = TrayCoordinator(
        host: host,
        throughput: throughput,
        settings: await memorySettings(),
        onShow: () => log.add('show'),
        onAdd: () => log.add('add'),
        onPauseAll: () => log.add('pause'),
        onResumeAll: () => log.add('resume'),
        onQuit: () => log.add('quit'),
      );
    });
    tearDown(() => tray.dispose());

    String label(String id) => host.entries.firstWhere((e) => e.id == id).label;

    test('the icon is put in the menu bar with an idle menu', () {
      expect(host.shown, isTrue);
      expect(label(TrayIds.summary), 'No active downloads');
      expect(
        host.entries.firstWhere((e) => e.id == TrayIds.pauseAll).enabled,
        isFalse,
      );
    });

    test('it shows how many are running and how fast', () async {
      throughput.set(active: 2, speed: 3 * 1024 * 1024);
      await flush();
      expect(label(TrayIds.summary), '2 downloading · 3.00 MB/s');
    });

    test('an unchanged menu is not rewritten', () async {
      throughput.set(active: 1, speed: 1024);
      await flush();
      final before = host.updates;
      throughput.set(active: 1, speed: 1024);
      await flush();
      expect(host.updates, before);
    });

    test('every entry does its job', () async {
      for (final id in [
        TrayIds.show,
        TrayIds.add,
        TrayIds.pauseAll,
        TrayIds.resumeAll,
        TrayIds.quit,
      ]) {
        host.choose(id);
      }
      await flush();
      expect(log, ['show', 'add', 'pause', 'resume', 'quit']);
    });

    test('the speed beside the icon follows its setting', () async {
      final settings = await memorySettings();
      final h = FakeTrayHost();
      final t = StubThroughput();
      final c = TrayCoordinator(
        host: h,
        throughput: t,
        settings: settings,
        onShow: () {},
        onAdd: () {},
        onPauseAll: () {},
        onResumeAll: () {},
        onQuit: () {},
      );
      t.set(active: 1, speed: 2048);
      await flush();
      expect(h.title, '2.00 KB/s');
      await settings.set(Keys.showSpeedInMenuBar, false);
      await flush();
      expect(h.title, isNull);
      await settings.set(Keys.showSpeedInMenuBar, true);
      await flush();
      expect(h.title, '2.00 KB/s');
      t.set(active: 0);
      await flush();
      expect(h.title, isNull);
      await c.dispose();
    });
  });

  group('power', () {
    late StubThroughput throughput;
    late FakeSleepBlocker sleep;
    late FakeLoginItem login;

    late SettingsRepository settings;
    Future<PowerCoordinator> start() async {
      settings = await memorySettings();
      return PowerCoordinator(
        throughput: throughput,
        settings: settings,
        sleep: sleep,
        loginItem: login,
      );
    }

    setUp(() {
      throughput = StubThroughput();
      sleep = FakeSleepBlocker();
      login = FakeLoginItem();
    });

    test('the Mac is held awake only while something runs', () async {
      final p = await start();
      expect(sleep.holding, isFalse);
      throughput.set(active: 1);
      await flush();
      expect(sleep.holding, isTrue);
      throughput.set(active: 3);
      await flush();
      expect(sleep.holds, 1);
      throughput.set(active: 0);
      await flush();
      expect(sleep.holding, isFalse);
      await p.dispose();
    });

    test('with the setting off it is never held', () async {
      final p = await start();
      await settings.set(Keys.keepAwake, false);
      throughput.set(active: 1);
      await flush();
      expect(sleep.holding, isFalse);
      await settings.set(Keys.keepAwake, true);
      await flush();
      expect(sleep.holding, isTrue);
      await settings.set(Keys.keepAwake, false);
      await flush();
      expect(sleep.holding, isFalse);
      await p.dispose();
    });

    test('quitting lets go', () async {
      final p = await start();
      throughput.set(active: 1);
      await flush();
      await p.dispose();
      expect(sleep.holding, isFalse);
    });

    test('the login item follows "Open at login"', () async {
      final p = await start();
      await flush();
      expect(login.enabled, isFalse);
      await settings.set(Keys.launchAtLogin, true);
      await flush();
      expect(login.enabled, isTrue);
      await settings.set(Keys.launchAtLogin, false);
      await flush();
      expect(login.enabled, isFalse);
      await p.dispose();
    });
  });

  group('caffeinate', () {
    test('it waits on our own process and stops when told', () async {
      final started = <List<String>>[];
      final fake = _FakeProcess();
      final blocker = CaffeinateSleepBlocker(
        processId: 4242,
        start: (exe, args) async {
          started.add([exe, ...args]);
          return fake;
        },
      );
      await blocker.hold();
      await blocker.hold();
      expect(started, [
        ['caffeinate', '-i', '-w', '4242'],
      ]);
      expect(blocker.holding, isTrue);
      await blocker.release();
      expect(fake.killed, isTrue);
      expect(blocker.holding, isFalse);
    });

    test('a missing caffeinate does not crash', () async {
      final blocker = CaffeinateSleepBlocker(
        start: (_, _) => throw const ProcessException('caffeinate', []),
      );
      await blocker.hold();
      expect(blocker.holding, isFalse);
    });
  });
}

class _FakeProcess implements Process {
  bool killed = false;
  final _exit = Completer<int>();

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!_exit.isCompleted) _exit.complete(0);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
