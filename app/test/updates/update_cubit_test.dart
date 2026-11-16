import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/cubits/update_cubit.dart';
import 'package:haul/data/setting_keys.dart';
import 'package:haul/data/settings_repository.dart';
import 'package:haul/services/updates/update_checker.dart';

import '../integration/integration_support.dart';
import '../support/test_deps.dart';

const info = UpdateInfo(
  version: '1.0.1',
  notes: 'notes',
  pageUrl: 'https://github.com/abdlim/haul/releases/tag/v1.0.1',
  downloadUrl:
      'https://github.com/abdlim/haul/releases/download/v1.0.1/Haul.dmg',
  fileName: 'Haul.dmg',
);

void main() {
  late SettingsRepository settings;
  late FakeUpdateSource source;
  late DateTime now;
  late UpdateCubit cubit;

  setUp(() async {
    settings = await memorySettings();
    source = FakeUpdateSource();
    now = DateTime(2026, 12, 1, 9);
    cubit = UpdateCubit(source: source, settings: settings, clock: () => now);
  });
  tearDown(() => cubit.close());

  test('an automatic check finds an update and records when it ran', () async {
    source.answer = info;
    await cubit.checkIfDue();
    expect(cubit.state.status, UpdateStatus.available);
    expect(cubit.state.info!.version, '1.0.1');
    expect(cubit.showBanner, isTrue);
    expect(
      settings.get(Keys.lastUpdateCheck),
      now.millisecondsSinceEpoch ~/ 1000,
    );
  });

  test('it asks at most once a day', () async {
    await cubit.checkIfDue();
    await cubit.checkIfDue();
    expect(source.calls, 1);
    now = now.add(const Duration(hours: 23));
    await cubit.checkIfDue();
    expect(source.calls, 1);
    now = now.add(const Duration(hours: 2));
    await cubit.checkIfDue();
    expect(source.calls, 2);
  });

  test('with the setting off it never asks by itself', () async {
    await settings.set(Keys.checkForUpdates, false);
    await cubit.checkIfDue();
    expect(source.calls, 0);
    expect(cubit.state.status, UpdateStatus.idle);
  });

  test('Check now asks even then, and says when Haul is up to date', () async {
    await settings.set(Keys.checkForUpdates, false);
    await cubit.checkNow();
    expect(source.calls, 1);
    expect(cubit.state.status, UpdateStatus.upToDate);
  });

  test('a failed automatic check says nothing; a manual one does', () async {
    source.failure = const UpdateCheckException('Could not reach GitHub.');
    await cubit.checkIfDue();
    expect(cubit.state.status, UpdateStatus.idle);
    expect(cubit.state.error, isNull);
    // And it is tried again soon, not a day later.
    expect(settings.get(Keys.lastUpdateCheck), isNull);

    await cubit.checkNow();
    expect(cubit.state.status, UpdateStatus.failed);
    expect(cubit.state.error, 'Could not reach GitHub.');
  });

  test('"Later" hides the banner for now only', () async {
    source.answer = info;
    await cubit.checkNow();
    cubit.later();
    expect(cubit.showBanner, isFalse);
    expect(cubit.state.status, UpdateStatus.available);
  });

  test('"Skip this version" keeps its banner away for good', () async {
    source.answer = info;
    await cubit.checkNow();
    await cubit.skip();
    expect(cubit.showBanner, isFalse);
    expect(settings.get(Keys.skippedUpdate), '1.0.1');

    // A new app run: same version stays hidden, a newer one shows.
    final again = UpdateCubit(
      source: source,
      settings: settings,
      clock: () => now,
    );
    await again.checkNow();
    expect(again.showBanner, isFalse);
    source.answer = const UpdateInfo(version: '1.0.2', notes: '', pageUrl: 'p');
    await again.checkNow();
    expect(again.showBanner, isTrue);
    await again.close();
  });

  test('Check now still reports a skipped version in Settings', () async {
    source.answer = info;
    await settings.set(Keys.skippedUpdate, '1.0.1');
    await cubit.checkNow();
    expect(cubit.state.status, UpdateStatus.available);
    expect(cubit.showBanner, isFalse);
  });

  test('two checks at once make one request', () async {
    final a = cubit.checkNow();
    final b = cubit.checkNow();
    await Future.wait([a, b]);
    expect(source.calls, 1);
  });
}
