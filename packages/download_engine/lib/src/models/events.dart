import 'download_snapshot.dart';
import 'segment.dart';

/// A message from the engine to the app.
sealed class EngineEvent {
  const EngineEvent();

  Map<String, Object?> toJson();

  factory EngineEvent.fromJson(Map<String, Object?> json) {
    switch (json['type']! as String) {
      case 'snapshot':
        return SnapshotEvent(
          DownloadSnapshot.fromJson(json['snapshot']! as Map<String, Object?>),
        );
      case 'progress':
        return ProgressEvent(
          id: json['id']! as String,
          downloadedBytes: json['downloadedBytes']! as int,
          totalBytes: json['totalBytes'] as int?,
          bytesPerSecond: (json['bytesPerSecond']! as num).toDouble(),
          eta: json['etaSeconds'] == null
              ? null
              : Duration(seconds: json['etaSeconds']! as int),
          segmentBytes: (json['segmentBytes']! as List<Object?>).cast<int>(),
          segments: [
            for (final s in (json['segments'] as List<Object?>? ?? const []))
              Segment.fromJson((s! as Map<Object?, Object?>).cast()),
          ],
        );
      case 'fileChanged':
        return FileChangedEvent(json['id']! as String);
      case 'removed':
        return RemovedEvent(json['id']! as String);
      default:
        throw FormatException('Unknown event type: ${json['type']}');
    }
  }
}

/// The full state of a download. Emitted on every status change and when a
/// download is paused, so it is safe to persist.
class SnapshotEvent extends EngineEvent {
  const SnapshotEvent(this.snapshot);
  final DownloadSnapshot snapshot;

  @override
  Map<String, Object?> toJson() => {
    'type': 'snapshot',
    'snapshot': snapshot.toJson(),
  };
}

/// Lightweight live numbers, at most four per second per download.
class ProgressEvent extends EngineEvent {
  const ProgressEvent({
    required this.id,
    required this.downloadedBytes,
    required this.bytesPerSecond,
    required this.segmentBytes,
    this.segments = const [],
    this.totalBytes,
    this.eta,
  });
  final String id;
  final int downloadedBytes;
  final int? totalBytes;
  final double bytesPerSecond;
  final Duration? eta;

  /// Bytes downloaded per segment, in segment order.
  final List<int> segmentBytes;

  /// The segments themselves, with their byte ranges and states, so a view
  /// can draw them live and show one dividing when it is split. Same order
  /// as [segmentBytes].
  final List<Segment> segments;

  @override
  Map<String, Object?> toJson() => {
    'type': 'progress',
    'id': id,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'bytesPerSecond': bytesPerSecond,
    'etaSeconds': eta?.inSeconds,
    'segmentBytes': segmentBytes,
    'segments': [for (final s in segments) s.toJson()],
  };
}

/// The server's file changed during a download, so it restarts from zero.
class FileChangedEvent extends EngineEvent {
  const FileChangedEvent(this.id);
  final String id;
  @override
  Map<String, Object?> toJson() => {'type': 'fileChanged', 'id': id};
}

class RemovedEvent extends EngineEvent {
  const RemovedEvent(this.id);
  final String id;
  @override
  Map<String, Object?> toJson() => {'type': 'removed', 'id': id};
}
