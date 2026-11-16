enum DownloadErrorCode {
  /// 404.
  notFound,

  /// 403.
  forbidden,

  /// 410: the link has expired.
  gone,

  /// 401 with no matching site login.
  authRequired,

  /// 407 from the proxy.
  proxyAuth,

  /// Socket, DNS, TLS or timeout trouble that ran out of retries.
  network,

  /// 5xx or other server-side trouble that ran out of retries.
  server,
  diskFull,

  /// The file on the server changed while we were downloading it.
  fileChanged,

  /// The server ignored a Range request.
  rangeIgnored,

  /// Anything we did not anticipate.
  unknown,
}

/// A typed download failure. Thrown inside the engine and carried to the UI
/// in snapshots.
class DownloadError implements Exception {
  const DownloadError(
    this.code,
    this.message, {
    this.retryable = false,
    this.overload = false,
  });

  final DownloadErrorCode code;
  final String message;

  /// Whether trying again could plausibly help. Not serialized: it only
  /// matters inside a running task.
  final bool retryable;

  /// The server pushed back on the number of connections (429, 503 or a
  /// refused connection). Not serialized, like [retryable].
  final bool overload;

  Map<String, Object?> toJson() => {'code': code.name, 'message': message};

  factory DownloadError.fromJson(Map<String, Object?> json) => DownloadError(
    DownloadErrorCode.values.byName(json['code']! as String),
    json['message']! as String,
  );

  @override
  String toString() => 'DownloadError(${code.name}: $message)';
}
