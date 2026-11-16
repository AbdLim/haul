import 'package:download_engine/download_engine.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:haul/app/cubits/downloads_cubit.dart';
import 'package:haul/app/cubits/throughput_cubit.dart';
import 'package:haul/data/database.dart';
import 'package:haul/data/downloads_dao.dart';
import 'package:haul/data/settings_repository.dart';

/// A download list the test can set directly.
class StubDownloads extends Cubit<DownloadsState> {
  StubDownloads() : super(const DownloadsState(loaded: true));

  /// Puts these downloads, by id and status, in the list.
  void set(Map<String, DownloadStatus> statuses, {String? error}) {
    emit(
      DownloadsState(
        loaded: true,
        downloads: [
          for (final e in statuses.entries)
            StoredDownload(
              snapshot: DownloadSnapshot(
                request: DownloadRequest(
                  id: e.key,
                  url: Uri.parse('https://example.com/${e.key}'),
                  saveDir: '/d',
                ),
                status: e.value,
                fileName: '${e.key}.zip',
                error: e.value == DownloadStatus.failed
                    ? DownloadError(DownloadErrorCode.network, 'x')
                    : null,
              ),
              source: 'manual',
              createdAt: DateTime(2026),
            ),
        ],
      ),
    );
  }
}

class StubThroughput extends Cubit<ThroughputState> {
  StubThroughput() : super(ThroughputState.idle());

  void set({required int active, double speed = 0}) => emit(
    ThroughputState(
      samples: ThroughputState.idle().samples,
      activeCount: active,
      speed: speed,
    ),
  );
}

Future<SettingsRepository> memorySettings() async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return SettingsRepository.open(HaulDatabase.inMemory());
}

/// Lets queued stream events and settings writes finish.
Future<void> flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
