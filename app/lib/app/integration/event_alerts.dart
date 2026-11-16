import 'dart:async';

import 'package:download_engine/download_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/downloads_dao.dart';
import '../../data/setting_keys.dart';
import '../../data/settings_repository.dart';
import '../../services/system/notifier.dart';
import '../../services/system/platform_services.dart';
import '../../services/system/sound_player.dart';
import '../cubits/downloads_cubit.dart';
import '../error_text.dart';

/// Tells the person when something finishes or fails: a banner and a sound,
/// each only if its setting allows. It watches the list for downloads that
/// change status; downloads already there when it starts are never announced.
class EventAlerts {
  EventAlerts({
    required StateStreamable<DownloadsState> downloads,
    required SettingsRepository settings,
    required Notifier notifier,
    required PlatformServices platform,
    SoundPlayer? sounds,
  }) : _settings = settings,
       _notifier = notifier,
       _platform = platform,
       _sounds = sounds {
    _prime(downloads.state);
    _sub = downloads.stream.listen(_onState);
  }

  /// Banners beyond this many at once become one summary.
  static const maxBannersAtOnce = 3;

  final SettingsRepository _settings;
  final Notifier _notifier;
  final PlatformServices _platform;
  final SoundPlayer? _sounds;
  late final StreamSubscription<DownloadsState> _sub;

  var _status = <String, DownloadStatus>{};
  var _primed = false;
  var _busy = false;
  var _completedWhileBusy = false;

  static bool _isBusy(DownloadStatus s) =>
      s == DownloadStatus.queued ||
      s == DownloadStatus.probing ||
      s == DownloadStatus.downloading;

  void _prime(DownloadsState state) {
    if (!state.loaded) return;
    _primed = true;
    _status = {for (final d in state.downloads) d.id: d.snapshot.status};
    _busy = state.downloads.any((d) => _isBusy(d.snapshot.status));
  }

  void _onState(DownloadsState state) {
    if (!_primed) return _prime(state);

    final finished = <StoredDownload>[];
    final failed = <StoredDownload>[];
    final next = <String, DownloadStatus>{};
    for (final d in state.downloads) {
      final cur = d.snapshot.status;
      final prev = _status[d.id];
      next[d.id] = cur;
      if (prev == cur) continue;
      if (cur == DownloadStatus.completed) finished.add(d);
      if (cur == DownloadStatus.failed) failed.add(d);
    }
    _status = next;

    final busyNow = state.downloads.any((d) => _isBusy(d.snapshot.status));
    if (!_busy && busyNow) _completedWhileBusy = false;
    if (finished.isNotEmpty) _completedWhileBusy = true;
    final queueEnded = _busy && !busyNow && _completedWhileBusy;
    if (_busy && !busyNow) _completedWhileBusy = false;
    _busy = busyNow;

    if (finished.isNotEmpty) _announceFinished(finished);
    if (failed.isNotEmpty) _announceFailed(failed);
    _playSounds(
      finished: finished.isNotEmpty,
      failed: failed.isNotEmpty,
      queueEnded: queueEnded,
    );
  }

  bool get _bannersOn => _settings.get(Keys.notificationsEnabled);

  void _announceFinished(List<StoredDownload> list) {
    if (!_bannersOn || !_settings.get(Keys.notifyOnComplete)) return;
    _banners(
      list,
      title: 'Download finished',
      body: (d) => _name(d),
      summary: (n) => '$n downloads finished',
      onClick: (d) {
        final path = d.snapshot.finalPath;
        if (path == null) return null;
        return () => _platform.revealInFileManager(path);
      },
    );
  }

  void _announceFailed(List<StoredDownload> list) {
    if (!_bannersOn || !_settings.get(Keys.notifyOnFailure)) return;
    _banners(
      list,
      title: 'Download failed',
      body: (d) => '${_name(d)}: ${plainError(d.snapshot.error)}',
      summary: (n) => '$n downloads failed',
      onClick: (_) => null,
    );
  }

  void _banners(
    List<StoredDownload> list, {
    required String title,
    required String Function(StoredDownload) body,
    required String Function(int) summary,
    required void Function()? Function(StoredDownload) onClick,
  }) {
    if (list.length > maxBannersAtOnce) {
      _notifier.show(title: title, body: summary(list.length));
      return;
    }
    for (final d in list) {
      _notifier.show(title: title, body: body(d), onClick: onClick(d));
    }
  }

  void _playSounds({
    required bool finished,
    required bool failed,
    required bool queueEnded,
  }) {
    final player = _sounds;
    if (player == null) return;
    // One sound per moment. The player drops a second one that overlaps, so
    // pick the most informative: "everything is done" beats "one is done".
    final queueSound = _settings.get(Keys.soundOnQueueFinished);
    final doneSound = _settings.get(Keys.soundOnComplete);
    final failSound = _settings.get(Keys.soundOnFailure);
    String? choice;
    if (failed && failSound != null) {
      choice = failSound;
    } else if (queueEnded && queueSound != null) {
      choice = queueSound;
    } else if (finished && doneSound != null) {
      choice = doneSound;
    }
    if (choice != null) unawaited(player.play(choice));
  }

  static String _name(StoredDownload d) =>
      d.snapshot.fileName ??
      d.snapshot.request.url.pathSegments.lastOrNull ??
      'A download';

  /// A banner that says a download from the browser was added.
  void announceQueued(String fileName) {
    if (!_bannersOn) return;
    _notifier.show(title: 'Download added', body: fileName);
  }

  Future<void> dispose() => _sub.cancel();
}
