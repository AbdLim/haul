import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

import '../test_support/range_server.dart';

void main() {
  late HttpClient client;
  late RangeServer server;
  setUp(() => client = HttpClient()..autoUncompress = false);
  tearDown(() async {
    client.close(force: true);
    await server.close();
  });

  DownloadRequest req(
    Uri url, {
    String? referrer,
    String? cookies,
    String? ua,
  }) => DownloadRequest(
    id: 't',
    url: url,
    saveDir: '/tmp',
    referrer: referrer,
    cookies: cookies,
    userAgent: ua,
  );

  Future<DownloadError> failure(Future<Object?> f) async {
    try {
      await f;
    } on DownloadError catch (e) {
      return e;
    }
    fail('expected a DownloadError');
  }

  test('206 with a size means ranges are supported', () async {
    server = await RangeServer.start(size: 123456);
    final r = await probe(req(server.url), client: client);
    expect(r.supportsRanges, isTrue);
    expect(r.totalBytes, 123456);
    expect(r.etag, server.etag);
    expect(r.lastModified, isNotNull);
    expect(r.contentType, contains('octet-stream'));
    expect(r.finalUrl, server.url);
    expect(server.log.single.range, 'bytes=0-0');
  });

  test('206 with an unknown total falls back to one stream', () async {
    server = await RangeServer.start(size: 5000);
    server.unknownTotal = true;
    final r = await probe(req(server.url), client: client);
    expect(r.supportsRanges, isFalse);
    expect(r.totalBytes, isNull);
  });

  test('200 means no range support, size from Content-Length', () async {
    server = await RangeServer.start(size: 4321, noRanges: true);
    final r = await probe(req(server.url), client: client);
    expect(r.supportsRanges, isFalse);
    expect(r.totalBytes, 4321);
  });

  test(
    'a server without ranges is not downloaded in full by the probe',
    () async {
      server = await RangeServer.start(
        size: 1 << 30,
        noRanges: true,
        throttleBytesPerSec: 1024 * 1024,
      );
      final watch = Stopwatch()..start();
      final r = await probe(req(server.url), client: client);
      expect(r.totalBytes, 1 << 30);
      expect(watch.elapsedMilliseconds, lessThan(2000));
      expect(server.log.single.bytesSent, lessThan(10 * 1024 * 1024));
    },
  );

  test('416 is retried without Range', () async {
    server = await RangeServer.start(size: 0);
    final r = await probe(req(server.url), client: client);
    expect(r.supportsRanges, isFalse);
    expect(r.totalBytes, 0);
    expect(server.log.map((e) => e.status), [416, 200]);
    expect(server.log.last.range, isNull);
  });

  test('404, 403, 410 and 401 give typed, non-retryable errors', () async {
    server = await RangeServer.start(size: 10);
    final cases = {
      404: DownloadErrorCode.notFound,
      403: DownloadErrorCode.forbidden,
      410: DownloadErrorCode.gone,
      401: DownloadErrorCode.authRequired,
    };
    for (final entry in cases.entries) {
      server.forceStatus = entry.key;
      final e = await failure(probe(req(server.url), client: client));
      expect(e.code, entry.value, reason: '${entry.key}');
      expect(e.retryable, isFalse);
    }
  });

  test('5xx and 429 are retryable', () async {
    server = await RangeServer.start(size: 10);
    for (final status in [500, 503, 429, 408]) {
      server.forceStatus = status;
      final e = await failure(probe(req(server.url), client: client));
      expect(e.retryable, isTrue, reason: '$status');
    }
  });

  test('a refused connection is a retryable network error', () async {
    server = await RangeServer.start(size: 10);
    final dead = server.url;
    await server.close();
    final e = await failure(probe(req(dead), client: client));
    expect(e.code, DownloadErrorCode.network);
    expect(e.retryable, isTrue);
    server = await RangeServer.start(size: 1); // so tearDown has something
  });

  test('follows redirects and reports the final URL', () async {
    server = await RangeServer.start(size: 777);
    final r = await probe(req(server.redirectFrom('/go')), client: client);
    expect(r.finalUrl, server.url);
    expect(r.totalBytes, 777);
  });

  test('sends identity encoding, cookies, referrer and user agent', () async {
    server = await RangeServer.start(size: 10);
    await probe(
      req(
        server.url,
        referrer: 'https://ref.test/page',
        cookies: 'a=1; b=2',
        ua: 'TestUA/9',
      ),
      client: client,
    );
    final h = server.log.single.headers;
    expect(h['accept-encoding'], 'identity');
    expect(h['cookie'], 'a=1; b=2');
    expect(h['referer'], 'https://ref.test/page');
    expect(h['user-agent'], 'TestUA/9');
  });

  test('uses a default browser user agent when none is given', () async {
    server = await RangeServer.start(size: 10);
    await probe(req(server.url), client: client);
    expect(server.log.single.headers['user-agent'], contains('Mozilla/5.0'));
  });

  test('reports Content-Disposition', () async {
    server = await RangeServer.start(
      size: 10,
      contentDisposition: 'attachment; filename="x.zip"',
    );
    final r = await probe(req(server.url), client: client);
    expect(r.contentDisposition, contains('x.zip'));
  });
}
