import 'dart:io';

import 'package:test/test.dart';

import '../test_support/range_server.dart';

Future<({int status, List<int> body, HttpHeaders headers})> get(
  Uri url, {
  Map<String, String> headers = const {},
  bool follow = false,
}) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(url);
    req.followRedirects = follow;
    headers.forEach(req.headers.set);
    final res = await req.close();
    final body = <int>[];
    await for (final c in res) {
      body.addAll(c);
    }
    return (status: res.statusCode, body: body, headers: res.headers);
  } finally {
    client.close(force: true);
  }
}

void main() {
  late RangeServer server;
  tearDown(() => server.close());

  test('serves a range with 206 and the right bytes', () async {
    server = await RangeServer.start(size: 100000);
    final r = await get(server.url, headers: {'range': 'bytes=1000-1999'});
    expect(r.status, 206);
    expect(r.headers.value('content-range'), 'bytes 1000-1999/100000');
    expect(r.body, server.bytes(1000, 1999));
  });

  test('serves the whole file with 200 when no range is asked', () async {
    server = await RangeServer.start(size: 50000);
    final r = await get(server.url);
    expect(r.status, 200);
    expect(r.body, server.allBytes);
    expect(r.headers.value('etag'), server.etag);
  });

  test('open-ended range runs to the end', () async {
    server = await RangeServer.start(size: 5000);
    final r = await get(server.url, headers: {'range': 'bytes=4000-'});
    expect(r.status, 206);
    expect(r.body, server.bytes(4000, 4999));
  });

  test('416 for a range past the end', () async {
    server = await RangeServer.start(size: 1000);
    final r = await get(server.url, headers: {'range': 'bytes=5000-'});
    expect(r.status, 416);
  });

  test('noRanges ignores Range and sends 200', () async {
    server = await RangeServer.start(size: 5000, noRanges: true);
    final r = await get(server.url, headers: {'range': 'bytes=10-20'});
    expect(r.status, 200);
    expect(r.body.length, 5000);
    expect(r.headers.value('accept-ranges'), isNull);
  });

  test('throttleBytesPerSec slows the response', () async {
    server = await RangeServer.start(
      size: 300 * 1024,
      throttleBytesPerSec: 600 * 1024,
    );
    final watch = Stopwatch()..start();
    final r = await get(server.url);
    expect(r.body.length, 300 * 1024);
    expect(watch.elapsedMilliseconds, greaterThan(400)); // ~0.5 s expected
    expect(watch.elapsedMilliseconds, lessThan(1500));
  });

  test('dropAfterBytes cuts the connection short', () async {
    server = await RangeServer.start(size: 200000, dropAfterBytes: 50000);
    final got = <int>[];
    final client = HttpClient();
    final req = await client.getUrl(server.url);
    final res = await req.close();
    try {
      await for (final c in res) {
        got.addAll(c);
      }
    } on Object {
      // expected: the connection is torn down early
    }
    client.close(force: true);
    expect(got.length, lessThan(200000));
    expect(got.length, lessThanOrEqualTo(50000));
    expect(server.log.single.bytesSent, 50000);
  });

  test('failNextRequests answers with the status n times', () async {
    server = await RangeServer.start(size: 1000);
    server.failNextRequests(2, 500);
    expect((await get(server.url)).status, 500);
    expect((await get(server.url)).status, 500);
    expect((await get(server.url)).status, 200);
  });

  test('maxConnections answers 503 above the limit', () async {
    server = await RangeServer.start(
      size: 400 * 1024,
      throttleBytesPerSec: 200 * 1024,
      maxConnections: 2,
    );
    final results = await Future.wait([
      for (var i = 0; i < 4; i++) get(server.url),
    ]);
    final statuses = results.map((r) => r.status).toList()..sort();
    expect(statuses, [200, 200, 503, 503]);
    expect(server.peakConcurrent, greaterThanOrEqualTo(3));
  });

  test('changeEtag makes If-Range fail, so the full file comes back', () async {
    server = await RangeServer.start(size: 5000);
    final old = server.etag;
    final ok = await get(
      server.url,
      headers: {'range': 'bytes=10-19', 'if-range': old},
    );
    expect(ok.status, 206);

    server.changeEtag();
    final stale = await get(
      server.url,
      headers: {'range': 'bytes=10-19', 'if-range': old},
    );
    expect(stale.status, 200);
    expect(stale.body.length, 5000);
    expect(server.etag, isNot(old));
  });

  test('redirectFrom sends a 302 to the file', () async {
    server = await RangeServer.start(size: 1000);
    final from = server.redirectFrom('/go');
    final r = await get(from);
    expect(r.status, 302);
    final followed = await get(from, follow: true);
    expect(followed.status, 200);
    expect(followed.body, server.allBytes);
  });

  test('Content-Disposition is sent when configured', () async {
    server = await RangeServer.start(
      size: 100,
      contentDisposition: 'attachment; filename="named.zip"',
    );
    final r = await get(server.url);
    expect(r.headers.value('content-disposition'), contains('named.zip'));
  });

  test('records every request', () async {
    server = await RangeServer.start(size: 5000);
    await get(server.url, headers: {'range': 'bytes=100-199', 'x-test': '1'});
    final e = server.log.single;
    expect(e.status, 206);
    expect(e.rangeStart, 100);
    expect(e.headers['x-test'], '1');
    expect(e.bytesSent, 100);
  });

  test('can serve a 1 GiB file without holding it in memory', () async {
    server = await RangeServer.start(size: 1 << 30);
    final r = await get(
      server.url,
      headers: {'range': 'bytes=1073741000-1073741823'},
    );
    expect(r.status, 206);
    expect(r.body.length, 824);
  });
}
