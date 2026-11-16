/// A download sent by the browser extension, as `POST /v1/downloads` carries
/// it. Only [url] and [source] are required.
class BridgePayload {
  const BridgePayload({
    required this.url,
    required this.source,
    this.finalUrl,
    this.fileName,
    this.referrer,
    this.userAgent,
    this.cookies,
    this.mimeType,
    this.fileSize,
  });

  final Uri url;

  /// `chrome`, `firefox`, ...
  final String source;
  final Uri? finalUrl;
  final String? fileName;
  final String? referrer;
  final String? userAgent;
  final String? cookies;
  final String? mimeType;
  final int? fileSize;

  /// Reads a decoded JSON body.
  ///
  /// Throws [BadPayload] when the body is not an object or a field has the
  /// wrong type (answered with 400), and [UnsupportedLink] when the link is
  /// not http or https (422).
  static BridgePayload parse(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const BadPayload('The body must be a JSON object');
    }
    String? text(String key, {bool required = false}) {
      final v = json[key];
      if (v == null) {
        if (required) throw BadPayload('"$key" is required');
        return null;
      }
      if (v is! String) throw BadPayload('"$key" must be text');
      return v.isEmpty && !required ? null : v;
    }

    final rawUrl = text('url', required: true)!;
    final source = text('source', required: true)!;
    final size = json['fileSize'];
    if (size != null && size is! int) {
      throw const BadPayload('"fileSize" must be a whole number');
    }

    final url = _link(rawUrl, 'url');
    final finalRaw = text('finalUrl');
    return BridgePayload(
      url: url,
      source: source,
      finalUrl: finalRaw == null ? null : _link(finalRaw, 'finalUrl'),
      fileName: text('fileName'),
      referrer: text('referrer'),
      userAgent: text('userAgent'),
      cookies: text('cookies'),
      mimeType: text('mimeType'),
      fileSize: size as int?,
    );
  }

  static Uri _link(String text, String field) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || !uri.hasScheme) {
      throw BadPayload('"$field" is not a link');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https' || uri.host.isEmpty) {
      throw UnsupportedLink('Only http and https links are accepted');
    }
    return uri;
  }
}

/// The body was not what the bridge expects: 400.
class BadPayload implements Exception {
  const BadPayload(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The link is not http or https: 422.
class UnsupportedLink implements Exception {
  const UnsupportedLink(this.message);
  final String message;
  @override
  String toString() => message;
}
