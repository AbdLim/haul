import 'dart:async';
import 'dart:io';

import 'models/download_error.dart';
import 'models/download_request.dart';
import 'models/network_config.dart';
import 'request_headers.dart';

class ProbeResult {
  const ProbeResult({
    required this.finalUrl,
    required this.supportsRanges,
    this.totalBytes,
    this.etag,
    this.lastModified,
    this.contentType,
    this.contentDisposition,
  });

  /// URL after redirects.
  final Uri finalUrl;

  /// True only for a `206` that also told us the total size.
  final bool supportsRanges;

  /// Null when the server does not say.
  final int? totalBytes;
  final String? etag;
  final String? lastModified;
  final String? contentType;
  final String? contentDisposition;
}

/// Finds out what a server can do: ranges, size, validators, final URL.
///
/// Throws [DownloadError]. Temporary failures have `retryable: true`.
Future<ProbeResult> probe(
  DownloadRequest request, {
  required HttpClient client,
  NetworkConfig? network,
  Uri? url,

  /// How long to wait for the server's answer before giving up (a retryable
  /// failure). A server that accepts the connection and then says nothing
  /// must not hold a download forever.
  Duration timeout = const Duration(seconds: 30),

  /// Called with each request as it is made, so the caller can abort it.
  void Function(HttpClientRequest request)? onRequest,
}) async {
  final target = url ?? request.url;
  final first = await _send(
    client,
    request,
    target,
    network,
    ranged: true,
    timeout: timeout,
    onRequest: onRequest,
  );

  if (first.status == 416) {
    // Range rejected (often an empty file). Ask again without it.
    final plain = await _send(
      client,
      request,
      target,
      network,
      ranged: false,
      timeout: timeout,
      onRequest: onRequest,
    );
    return _fromResponse(plain, target, ranged: false);
  }
  return _fromResponse(first, target, ranged: true);
}

class _Response {
  _Response(this.status, this.headers, this.redirects, this.contentLength);
  final int status;
  final HttpHeaders headers;
  final List<RedirectInfo> redirects;
  final int contentLength;
}

Future<_Response> _send(
  HttpClient client,
  DownloadRequest request,
  Uri url,
  NetworkConfig? network, {
  required bool ranged,
  required Duration timeout,
  void Function(HttpClientRequest request)? onRequest,
}) async {
  HttpClientRequest? http;
  try {
    http = await client.getUrl(url);
    onRequest?.call(http);
    http.followRedirects = true;
    http.maxRedirects = 10;
    applyRequestHeaders(http, request, network: network);
    if (ranged) http.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
    final response = await http.close().timeout(timeout);
    final result = _Response(
      response.statusCode,
      response.headers,
      response.redirects,
      response.contentLength,
    );
    // Headers are all we need. Aborting stops a server that ignores Range
    // from streaming the whole file at us.
    http.abort();
    return result;
  } on SocketException catch (e) {
    throw DownloadError(DownloadErrorCode.network, e.message, retryable: true);
  } on TlsException catch (e) {
    throw DownloadError(DownloadErrorCode.network, 'TLS error: ${e.message}');
  } on HttpException catch (e) {
    throw DownloadError(DownloadErrorCode.network, e.message, retryable: true);
  } on TimeoutException {
    http?.abort();
    throw const DownloadError(
      DownloadErrorCode.network,
      'Timed out',
      retryable: true,
    );
  }
}

ProbeResult _fromResponse(_Response r, Uri requested, {required bool ranged}) {
  switch (r.status) {
    case 401:
      throw const DownloadError(
        DownloadErrorCode.authRequired,
        'This site needs a login',
      );
    case 403:
      throw const DownloadError(
        DownloadErrorCode.forbidden,
        'The server refused access',
      );
    case 404:
      throw const DownloadError(DownloadErrorCode.notFound, 'File not found');
    case 407:
      throw const DownloadError(
        DownloadErrorCode.proxyAuth,
        'The proxy needs a login',
      );
    case 410:
      throw const DownloadError(DownloadErrorCode.gone, 'The link has expired');
  }
  if (r.status == 408 || r.status == 429 || r.status >= 500) {
    throw DownloadError(
      DownloadErrorCode.server,
      'Server responded with ${r.status}',
      retryable: true,
    );
  }
  if (r.status != 200 && r.status != 206) {
    throw DownloadError(
      DownloadErrorCode.unknown,
      'Unexpected response ${r.status}',
    );
  }

  var base = requested;
  for (final hop in r.redirects) {
    base = base.resolveUri(hop.location);
  }

  int? total;
  var ranges = false;
  if (r.status == 206) {
    total = _totalFromContentRange(
      firstHeader(r.headers, HttpHeaders.contentRangeHeader),
    );
    // A 206 without a known total can't be split, so treat it as one stream.
    ranges = total != null;
  } else if (r.contentLength >= 0) {
    total = r.contentLength;
  }

  return ProbeResult(
    finalUrl: base,
    supportsRanges: ranges,
    totalBytes: total,
    etag: firstHeader(r.headers, HttpHeaders.etagHeader),
    lastModified: firstHeader(r.headers, HttpHeaders.lastModifiedHeader),
    contentType: firstHeader(r.headers, HttpHeaders.contentTypeHeader),
    contentDisposition: firstHeader(r.headers, 'content-disposition'),
  );
}

/// `bytes 0-0/12345` gives 12345. `*` or garbage gives null.
int? _totalFromContentRange(String? header) {
  if (header == null) return null;
  final slash = header.lastIndexOf('/');
  if (slash == -1) return null;
  return int.tryParse(header.substring(slash + 1).trim());
}
