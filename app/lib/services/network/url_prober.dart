import 'dart:async';
import 'dart:io';

import 'package:download_engine/download_engine.dart' as eng;

/// What the app learns about a link before downloading it.
class UrlInfo {
  const UrlInfo({
    required this.fileName,
    required this.supportsRanges,
    this.size,
  });

  /// The name the server suggests, or the end of the link.
  final String fileName;

  /// Null when the server does not say.
  final int? size;
  final bool supportsRanges;
}

/// A failure to look at a link, with words fit to show.
class UrlProbeException implements Exception {
  const UrlProbeException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Looks at a link without downloading it.
abstract class UrlProber {
  /// Throws [UrlProbeException] if the link cannot be reached or is refused.
  ///
  /// [referrer], [cookies] and [userAgent] are what the browser sent along,
  /// so a file behind a login can be looked at as the browser would.
  Future<UrlInfo> probe(
    Uri url, {
    String? referrer,
    String? cookies,
    String? userAgent,
  });
}

/// Uses the engine's own probe, so what the dialog shows is exactly what the
/// download will find.
class EngineUrlProber implements UrlProber {
  EngineUrlProber({this.timeout = const Duration(seconds: 15), this.network});

  final Duration timeout;

  /// Site logins and the default user agent, if any, are applied.
  final eng.NetworkConfig Function()? network;

  @override
  Future<UrlInfo> probe(
    Uri url, {
    String? referrer,
    String? cookies,
    String? userAgent,
  }) async {
    final client = HttpClient()..autoUncompress = false;
    try {
      final result = await eng
          .probe(
            eng.DownloadRequest(
              id: 'probe',
              url: url,
              saveDir: '',
              referrer: referrer,
              cookies: cookies,
              userAgent: userAgent,
            ),
            client: client,
            network: network?.call(),
          )
          .timeout(timeout);
      return UrlInfo(
        fileName: eng.resolveFileName(
          finalUrl: result.finalUrl,
          contentDisposition: result.contentDisposition,
        ),
        size: result.totalBytes,
        supportsRanges: result.supportsRanges,
      );
    } on eng.DownloadError catch (e) {
      throw UrlProbeException(_words(e));
    } on TimeoutException {
      throw const UrlProbeException('The server took too long to answer');
    } finally {
      client.close(force: true);
    }
  }

  static String _words(eng.DownloadError e) => switch (e.code) {
    eng.DownloadErrorCode.notFound => 'The file was not found on the server',
    eng.DownloadErrorCode.forbidden => 'The server refused access',
    eng.DownloadErrorCode.gone => 'This link has expired',
    eng.DownloadErrorCode.authRequired => 'This site needs a login',
    eng.DownloadErrorCode.proxyAuth => 'The proxy needs a login',
    eng.DownloadErrorCode.network => 'Could not reach the server',
    eng.DownloadErrorCode.server => 'The server is not answering properly',
    _ => 'Could not read this link',
  };
}
