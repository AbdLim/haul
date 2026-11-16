import 'dart:async';

import 'package:download_engine/download_engine.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/categories_repository.dart';
import '../../data/downloads_dao.dart';
import '../../data/downloads_repository.dart';

class DownloadsState extends Equatable {
  const DownloadsState({
    this.downloads = const [],
    this.categories = const [],
    this.loaded = false,
  });

  /// Oldest first, as stored.
  final List<StoredDownload> downloads;
  final List<DownloadCategory> categories;

  /// False until the first read of the database has come back, so the UI can
  /// tell "still loading" from "nothing here".
  final bool loaded;

  StoredDownload? byId(String id) {
    for (final d in downloads) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  List<Object?> get props => [downloads, categories, loaded];
}

/// The download list and the categories. It changes when a download is
/// added, removed or changes status, and a few times a minute while data
/// is checkpointed; live speed is in [LiveCubit] so it never rebuilds this.
class DownloadsCubit extends Cubit<DownloadsState> {
  DownloadsCubit(this._repo, this._categories) : super(const DownloadsState()) {
    _downloadsSub = _repo.watchDownloads().listen(
      (list) => emit(
        DownloadsState(
          downloads: list,
          categories: state.categories,
          loaded: true,
        ),
      ),
    );
    _categoriesSub = _categories.watchAll().listen(
      (cats) => emit(
        DownloadsState(
          downloads: state.downloads,
          categories: cats,
          loaded: state.loaded,
        ),
      ),
    );
  }

  final DownloadsRepository _repo;
  final CategoriesRepository _categories;
  late final StreamSubscription<List<StoredDownload>> _downloadsSub;
  late final StreamSubscription<List<DownloadCategory>> _categoriesSub;

  void pause(String id) => _repo.pause(id);
  void resume(String id) => _repo.resume(id);
  void cancel(String id) => _repo.cancel(id);
  void remove(String id) => _repo.remove(id);

  /// Pauses everything that is running or waiting.
  void pauseAll() {
    for (final d in state.downloads) {
      final s = d.snapshot.status;
      if (s.isActive || s == DownloadStatus.queued) _repo.pause(d.id);
    }
  }

  /// Resumes everything that is paused or failed, oldest first.
  void resumeAll() {
    for (final d in state.downloads) {
      if (d.snapshot.status.canResume &&
          d.snapshot.status != DownloadStatus.needsRefresh) {
        _repo.resume(d.id);
      }
    }
  }

  @override
  Future<void> close() async {
    await _downloadsSub.cancel();
    await _categoriesSub.cancel();
    return super.close();
  }
}

/// Live numbers for downloads that are running: speed, ETA, bytes per
/// segment. Kept apart from [DownloadsCubit] because it changes four times a
/// second per download and only individual rows need to listen.
class LiveCubit extends Cubit<Map<String, ProgressEvent>> {
  LiveCubit(DownloadsRepository repo) : super(const {}) {
    _sub = repo.progress.listen((e) => emit({...state, e.id: e}));
    _statusSub = repo.watchDownloads().listen(_dropFinished);
  }

  late final StreamSubscription<ProgressEvent> _sub;
  late final StreamSubscription<List<StoredDownload>> _statusSub;

  /// Live data only means something while a download is running.
  void _dropFinished(List<StoredDownload> list) {
    final running = {
      for (final d in list)
        if (d.snapshot.status == DownloadStatus.downloading) d.id,
    };
    final stale = state.keys.where((id) => !running.contains(id)).toList();
    if (stale.isEmpty) return;
    emit({
      for (final e in state.entries)
        if (!stale.contains(e.key)) e.key: e.value,
    });
  }

  /// Combined speed of everything running, in bytes per second.
  double get totalSpeed =>
      state.values.fold(0.0, (sum, e) => sum + e.bytesPerSecond);

  @override
  Future<void> close() async {
    await _sub.cancel();
    await _statusSub.cancel();
    return super.close();
  }
}
