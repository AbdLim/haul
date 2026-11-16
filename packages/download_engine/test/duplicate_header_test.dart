import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

/// Some servers send the same header twice. `HttpHeaders.value` throws on
/// that, which used to make such a download fail and retry forever.
void main() {
  test('a response with two Content-Disposition headers is read', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((socket) {
      socket.listen((_) {
        socket.write(
          'HTTP/1.1 206 Partial Content\r\n'
          'Content-Range: bytes 0-0/5000\r\n'
          'Content-Length: 1\r\n'
          'Content-Disposition: attachment; filename="first.mkv"\r\n'
          'Content-Disposition: attachment; filename="second.mkv"\r\n'
          'ETag: "a"\r\n'
          'ETag: "b"\r\n'
          'Connection: close\r\n\r\nx',
        );
        socket.close();
      });
    });
    final client = HttpClient();
    final r = await probe(
      DownloadRequest(
        id: 'd',
        url: Uri.parse('http://127.0.0.1:${server.port}/f'),
        saveDir: '/tmp',
      ),
      client: client,
    );
    expect(r.totalBytes, 5000);
    expect(r.supportsRanges, isTrue);
    expect(r.contentDisposition, contains('first.mkv'));
    expect(r.etag, '"a"');
    client.close(force: true);
    await server.close();
  });
}
