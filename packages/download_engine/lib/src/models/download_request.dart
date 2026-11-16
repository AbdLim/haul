/// What the caller asks us to download.
class DownloadRequest {
  const DownloadRequest({
    required this.id,
    required this.url,
    required this.saveDir,
    this.fileName,
    this.referrer,
    this.userAgent,
    this.cookies,
    this.maxConnections = 8,
  });

  final String id;
  final Uri url;
  final String saveDir;

  /// Overrides whatever the server suggests.
  final String? fileName;
  final String? referrer;
  final String? userAgent;
  final String? cookies;
  final int maxConnections;

  DownloadRequest copyWith({
    Uri? url,
    String? referrer,
    String? userAgent,
    String? cookies,
    int? maxConnections,
  }) => DownloadRequest(
    id: id,
    url: url ?? this.url,
    saveDir: saveDir,
    fileName: fileName,
    referrer: referrer ?? this.referrer,
    userAgent: userAgent ?? this.userAgent,
    cookies: cookies ?? this.cookies,
    maxConnections: maxConnections ?? this.maxConnections,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'url': url.toString(),
    'saveDir': saveDir,
    'fileName': fileName,
    'referrer': referrer,
    'userAgent': userAgent,
    'cookies': cookies,
    'maxConnections': maxConnections,
  };

  factory DownloadRequest.fromJson(Map<String, Object?> json) =>
      DownloadRequest(
        id: json['id']! as String,
        url: Uri.parse(json['url']! as String),
        saveDir: json['saveDir']! as String,
        fileName: json['fileName'] as String?,
        referrer: json['referrer'] as String?,
        userAgent: json['userAgent'] as String?,
        cookies: json['cookies'] as String?,
        maxConnections: json['maxConnections']! as int,
      );
}
