import 'package:download_engine/download_engine.dart';

/// What to tell a person about a failure. Always plain words, never a code.
String plainError(DownloadError? e) {
  if (e == null) return 'Something went wrong';
  return switch (e.code) {
    DownloadErrorCode.notFound => 'The file was not found on the server',
    DownloadErrorCode.forbidden => 'The server refused access',
    DownloadErrorCode.gone => 'This link has expired',
    DownloadErrorCode.authRequired => 'This site needs a login',
    DownloadErrorCode.proxyAuth => 'The proxy needs a login',
    DownloadErrorCode.network => 'The connection kept failing',
    DownloadErrorCode.server => 'The server kept returning errors',
    DownloadErrorCode.diskFull => 'The disk is full',
    DownloadErrorCode.fileChanged => 'The file changed on the server',
    DownloadErrorCode.rangeIgnored => 'The server does not allow resuming',
    DownloadErrorCode.unknown => 'Something went wrong',
  };
}
