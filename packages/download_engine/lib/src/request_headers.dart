import 'dart:convert';
import 'dart:io';

import 'models/download_request.dart';
import 'models/network_config.dart';

/// A desktop browser string used when the caller has none.
const defaultUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
    '(KHTML, like Gecko) Version/17.0 Safari/605.1.15';

/// Applies the headers every request must carry. `Accept-Encoding: identity`
/// keeps byte ranges aligned with bytes on disk.
void applyRequestHeaders(
  HttpClientRequest http,
  DownloadRequest request, {
  NetworkConfig? network,
  String? fallbackUserAgent,
}) {
  http.headers
    ..set(HttpHeaders.acceptEncodingHeader, 'identity')
    ..set(
      HttpHeaders.userAgentHeader,
      request.userAgent ??
          network?.defaultUserAgent ??
          fallbackUserAgent ??
          defaultUserAgent,
    );
  final referrer = request.referrer;
  if (referrer != null) http.headers.set(HttpHeaders.refererHeader, referrer);
  final cookies = request.cookies;
  if (cookies != null) http.headers.set(HttpHeaders.cookieHeader, cookies);

  // Site login, sent only to the host the download was asked for.
  final login = network?.siteLogins[request.url.host.toLowerCase()];
  if (login != null) {
    final token = base64.encode(
      utf8.encode('${login.username}:${login.password}'),
    );
    http.headers.set(HttpHeaders.authorizationHeader, 'Basic $token');
  }
}

/// The first value of a response header, or null. `HttpHeaders.value` throws
/// when a server sends the same header twice (some do, for
/// `Content-Disposition`), which would fail the whole download.
String? firstHeader(HttpHeaders headers, String name) {
  final all = headers[name];
  return all == null || all.isEmpty ? null : all.first;
}
