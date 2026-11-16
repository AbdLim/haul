import 'package:download_engine/download_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/cubits/downloads_cubit.dart';
import 'package:haul/app/integration/event_alerts.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/data/settings_repository.dart';
import 'package:haul/services/system/notifier.dart';

import '../support/test_deps.dart';
import 'integration_support.dart';

void main() {
  late StubDownloads downloads;
  late SettingsRepository settings;
  late FakeNotifier notifier;
  late FakeSoundPlayer sounds;
  late FakePlatform platform;
  late EventAlerts alerts;

  Future<void> start({Map<String, DownloadStatus>? initial}) async {
    downloads = StubDownloads();
    if (initial != null) downloads.set(initial);
    settings = await memorySettings();
    notifier = FakeNotifier();
    sounds = FakeSoundPlayer();
    platform = FakePlatform();
    alerts = EventAlerts(
      downloads: downloads,
      settings: settings,
      notifier: notifier,
      platform: platform,
      sounds: sounds,
    );
  }

  tearDown(() => alerts.dispose());

  test('a download that finishes shows a banner with its name', () async {
    await start(initial: {'a': DownloadStatus.downloading});
    downloads.set({'a': DownloadStatus.completed});
    await flush();
    expect(notifier.shown.single.title, 'Download finished');
    expect(notifier.shown.single.body, 'a.zip');
  });

  test('clicking the banner reveals the file', () async {
    await start(initial: {'a': DownloadStatus.downloading});
    downloads.set({'a': DownloadStatus.completed});
    await flush();
    notifier.shown.single.onClick!();
    expect(platform.revealed, hasLength(1));
    expect(platform.revealed.single, endsWith('a.zip'));
  });

  test('a failure says why, in plain words', () async {
    await start(initial: {'a': DownloadStatus.downloading});
    downloads.set({'a': DownloadStatus.failed});
    await flush();
    expect(notifier.shown.single.title, 'Download failed');
    expect(notifier.shown.single.body, 'a.zip: The connection kept failing');
  });

  test('downloads already finished at start are not announced', () async {
    await start(initial: {'a': DownloadStatus.completed});
    downloads.set({'a': DownloadStatus.completed, 'b': DownloadStatus.paused});
    await flush();
    expect(notifier.shown, isEmpty);
    expect(sounds.played, isEmpty);
  });

  test('nothing appears while the list is still loading', () async {
    final loading = _Plain();
    settings = await memorySettings();
    notifier = FakeNotifier();
    alerts = EventAlerts(
      downloads: loading,
      settings: settings,
      notifier: notifier,
      platform: FakePlatform(),
    );
    final d = StubDownloads()..set({'a': DownloadStatus.completed});
    loading.put(d.state);
    await flush();
    expect(notifier.shown, isEmpty);
  });

  test('the master switch silences every banner', () async {
    await start(initial: {'a': DownloadStatus.downloading});
    await settings.set(Keys.notificationsEnabled, false);
    downloads.set({'a': DownloadStatus.completed});
    await flush();
    downloads.set({'a': DownloadStatus.failed});
    await flush();
    expect(notifier.shown, isEmpty);
  });

  test('each event has its own switch', () async {
    await start(
      initial: {
        'a': DownloadStatus.downloading,
        'b': DownloadStatus.downloading,
      },
    );
    await settings.set(Keys.notifyOnComplete, false);
    downloads.set({'a': DownloadStatus.completed, 'b': DownloadStatus.failed});
    await flush();
    expect(notifier.shown.map((n) => n.title), ['Download failed']);
  });

  test('a burst of finishes becomes one summary', () async {
    await start(
      initial: {
        for (final i in 'abcde'.split('')) i: DownloadStatus.downloading,
      },
    );
    downloads.set({
      for (final i in 'abcde'.split('')) i: DownloadStatus.completed,
    });
    await flush();
    expect(notifier.shown.single.body, '5 downloads finished');
  });

  group('sounds', () {
    test('a finish plays the chosen sound once', () async {
      await start(
        initial: {'a': DownloadStatus.downloading, 'b': DownloadStatus.paused},
      );
      await settings.set(Keys.soundOnComplete, 'Glass');
      downloads.set({
        'a': DownloadStatus.completed,
        'b': DownloadStatus.paused,
      });
      await flush();
      expect(sounds.played, ['Glass']);
    });

    test('with no sound chosen it is silent', () async {
      await start(initial: {'a': DownloadStatus.downloading});
      downloads.set({'a': DownloadStatus.completed});
      await flush();
      expect(sounds.played, isEmpty);
    });

    test('a failure plays its own sound', () async {
      await start(initial: {'a': DownloadStatus.downloading});
      await settings.set(Keys.soundOnFailure, 'Basso');
      await settings.set(Keys.soundOnComplete, 'Glass');
      downloads.set({'a': DownloadStatus.failed});
      await flush();
      expect(sounds.played, ['Basso']);
    });

    test(
      'when the queue runs empty its sound beats the finish sound',
      () async {
        await start(initial: {'a': DownloadStatus.downloading});
        await settings.set(Keys.soundOnComplete, 'Glass');
        await settings.set(Keys.soundOnQueueFinished, 'Hero');
        downloads.set({'a': DownloadStatus.completed});
        await flush();
        expect(sounds.played, ['Hero']);
      },
    );

    test(
      'with other downloads still running only the finish sound plays',
      () async {
        await start(
          initial: {
            'a': DownloadStatus.downloading,
            'b': DownloadStatus.downloading,
          },
        );
        await settings.set(Keys.soundOnComplete, 'Glass');
        await settings.set(Keys.soundOnQueueFinished, 'Hero');
        downloads.set({
          'a': DownloadStatus.completed,
          'b': DownloadStatus.downloading,
        });
        await flush();
        expect(sounds.played, ['Glass']);
      },
    );

    test('pausing everything is not "queue finished"', () async {
      await start(initial: {'a': DownloadStatus.downloading});
      await settings.set(Keys.soundOnQueueFinished, 'Hero');
      downloads.set({'a': DownloadStatus.paused});
      await flush();
      expect(sounds.played, isEmpty);
    });

    test('sounds do not depend on the banner switch', () async {
      await start(initial: {'a': DownloadStatus.downloading});
      await settings.set(Keys.notificationsEnabled, false);
      await settings.set(Keys.soundOnComplete, 'Glass');
      downloads.set({'a': DownloadStatus.completed});
      await flush();
      expect(sounds.played, ['Glass']);
    });
  });

  test('a download added from the browser is confirmed', () async {
    await start();
    alerts.announceQueued('big.iso');
    expect(notifier.shown.single.body, 'big.iso');
    await settings.set(Keys.notificationsEnabled, false);
    alerts.announceQueued('other.iso');
    expect(notifier.shown, hasLength(1));
  });
}

class _Plain extends Cubit<DownloadsState> {
  _Plain() : super(const DownloadsState());

  void put(DownloadsState s) => emit(s);
}
