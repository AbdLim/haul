import 'download_error.dart';
import 'download_request.dart';
import 'download_status.dart';
import 'segment.dart';

/// Everything needed to show a download or continue it later.
class DownloadSnapshot {
  const DownloadSnapshot({
    required this.request,
    this.status = DownloadStatus.queued,
    this.finalUrl,
    this.fileName,
    this.totalBytes,
    this.supportsRanges = false,
    this.resumable = true,
    this.etag,
    this.lastModified,
    this.contentType,
    this.segments = const [],
    this.error,
  });

  final DownloadRequest request;
  final DownloadStatus status;

  /// URL after redirects, as found by the probe.
  final Uri? finalUrl;

  /// Resolved name, with collisions already handled. Null until probed.
  final String? fileName;
  final int? totalBytes;
  final bool supportsRanges;

  /// False for single-connection downloads: pausing loses progress.
  final bool resumable;
  final String? etag;
  final String? lastModified;
  final String? contentType;
  final List<Segment> segments;
  final DownloadError? error;

  String get id => request.id;

  int get downloadedBytes => segments.fold(0, (sum, s) => sum + s.downloaded);

  String? get finalPath =>
      fileName == null ? null : '${request.saveDir}/$fileName';
  String? get partPath => finalPath == null ? null : '$finalPath.part';

  DownloadSnapshot copyWith({
    DownloadRequest? request,
    DownloadStatus? status,
    Uri? finalUrl,
    String? fileName,
    int? totalBytes,
    bool? supportsRanges,
    bool? resumable,
    String? etag,
    String? lastModified,
    String? contentType,
    List<Segment>? segments,
    DownloadError? error,
    bool clearError = false,
  }) => DownloadSnapshot(
    request: request ?? this.request,
    status: status ?? this.status,
    finalUrl: finalUrl ?? this.finalUrl,
    fileName: fileName ?? this.fileName,
    totalBytes: totalBytes ?? this.totalBytes,
    supportsRanges: supportsRanges ?? this.supportsRanges,
    resumable: resumable ?? this.resumable,
    etag: etag ?? this.etag,
    lastModified: lastModified ?? this.lastModified,
    contentType: contentType ?? this.contentType,
    segments: segments ?? this.segments,
    error: clearError ? null : (error ?? this.error),
  );

  /// The same download pointed at a fresh link: new URL (and optionally new
  /// referrer, cookies or user agent), same file name, same segments. Used
  /// after `needsRefresh`.
  DownloadSnapshot withRefreshedUrl(
    Uri url, {
    String? referrer,
    String? cookies,
    String? userAgent,
  }) => copyWith(
    request: request.copyWith(
      url: url,
      referrer: referrer,
      cookies: cookies,
      userAgent: userAgent,
    ),
    status: DownloadStatus.queued,
    clearError: true,
  );

  Map<String, Object?> toJson() => {
    'request': request.toJson(),
    'status': status.name,
    'finalUrl': finalUrl?.toString(),
    'fileName': fileName,
    'totalBytes': totalBytes,
    'supportsRanges': supportsRanges,
    'resumable': resumable,
    'etag': etag,
    'lastModified': lastModified,
    'contentType': contentType,
    'segments': [for (final s in segments) s.toJson()],
    'error': error?.toJson(),
  };

  factory DownloadSnapshot.fromJson(Map<String, Object?> json) =>
      DownloadSnapshot(
        request: DownloadRequest.fromJson(
          json['request']! as Map<String, Object?>,
        ),
        status: DownloadStatus.values.byName(json['status']! as String),
        finalUrl: json['finalUrl'] == null
            ? null
            : Uri.parse(json['finalUrl']! as String),
        fileName: json['fileName'] as String?,
        totalBytes: json['totalBytes'] as int?,
        supportsRanges: json['supportsRanges']! as bool,
        resumable: json['resumable']! as bool,
        etag: json['etag'] as String?,
        lastModified: json['lastModified'] as String?,
        contentType: json['contentType'] as String?,
        segments: [
          for (final s in json['segments']! as List<Object?>)
            Segment.fromJson(s! as Map<String, Object?>),
        ],
        error: json['error'] == null
            ? null
            : DownloadError.fromJson(json['error']! as Map<String, Object?>),
      );
}
