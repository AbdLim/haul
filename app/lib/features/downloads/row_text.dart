import 'package:download_engine/download_engine.dart';

import '../../app/components/components.dart';
import '../../app/error_text.dart';
import '../../app/format.dart';

/// The second line of a row: sizes, speed and time left while it runs, and
/// the state in words otherwise.
String rowSubtitle(DownloadSnapshot s, ProgressEvent? live) {
  final total = s.totalBytes ?? live?.totalBytes;
  final done = s.status == DownloadStatus.downloading && live != null
      ? live.downloadedBytes
      : s.downloadedBytes;
  String sizes() => total == null
      ? formatBytes(done)
      : '${formatBytes(done)} of ${formatBytes(total)}';

  switch (s.status) {
    case DownloadStatus.queued:
      return 'Waiting in the queue';
    case DownloadStatus.probing:
      return 'Connecting…';
    case DownloadStatus.downloading:
      final speed = live?.bytesPerSecond ?? 0;
      if (speed <= 0) return sizes();
      final eta = live?.eta;
      return [
        sizes(),
        formatSpeed(speed),
        if (eta != null) '${formatEta(eta)} left',
      ].join(' · ');
    case DownloadStatus.paused:
      return s.resumable || done == 0
          ? 'Paused · ${sizes()}'
          : 'Paused · will start over when resumed';
    case DownloadStatus.completed:
      return total == null ? 'Completed' : 'Completed · ${formatBytes(total)}';
    case DownloadStatus.failed:
      return plainError(s.error);
    case DownloadStatus.needsRefresh:
      return 'Link expired · needs a fresh link';
  }
}

/// How far along a download is, 0 to 1, or null when the size is unknown.
double? rowProgress(DownloadSnapshot s, ProgressEvent? live) {
  if (s.status == DownloadStatus.completed) return 1;
  final total = s.totalBytes ?? live?.totalBytes;
  if (total == null || total <= 0) return null;
  final done = s.status == DownloadStatus.downloading && live != null
      ? live.downloadedBytes
      : s.downloadedBytes;
  return (done / total).clamp(0.0, 1.0);
}

/// The bar's colour for a state.
HaulProgressTone rowTone(DownloadStatus status) => switch (status) {
  DownloadStatus.downloading ||
  DownloadStatus.probing => HaulProgressTone.accent,
  DownloadStatus.completed => HaulProgressTone.success,
  DownloadStatus.failed ||
  DownloadStatus.needsRefresh => HaulProgressTone.danger,
  DownloadStatus.queued || DownloadStatus.paused => HaulProgressTone.neutral,
};

/// A name to show before the server has told us one: the end of the link.
String rowTitle(DownloadSnapshot s) {
  final name = s.fileName ?? s.request.fileName;
  if (name != null && name.isNotEmpty) return name;
  final segments = s.request.url.pathSegments.where((p) => p.isNotEmpty);
  return segments.isEmpty ? s.request.url.host : segments.last;
}
