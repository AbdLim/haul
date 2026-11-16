import 'dart:async';
import 'dart:io';

import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

import '../test_support/range_server.dart';

const mib = 1024 * 1024;

/// A clock the test drives by hand, so no real time passes.
class VirtualTime {
  Duration now = Duration.zero;
  final _timers = <(Duration, Completer<void>)>[];

  Duration clock() => now;

  Future<void> sleep(Duration d) {
    final c = Completer<void>();
    _timers.add((now + d, c));
    return c.future;
  }

  /// Runs until every pending sleep has fired, advancing time as needed.
  Future<void> drain(bool Function() stillWorking) async {
    while (stillWorking()) {
      await Future<void>.delayed(Duration.zero);
      if (_timers.isEmpty) continue;
      _timers.sort((a, b) => a.$1.compareTo(b.$1));
      final next = _timers.removeAt(0);
      if (next.$1 > now) now = next.$1;
      next.$2.complete();
    }
  }
}

void main() {
  group('RateLimiter (virtual time)', () {
    test('unlimited never waits', () async {
      final t = VirtualTime();
      final l = RateLimiter(clock: t.clock, sleep: t.sleep);
      await l.acquire(100 * mib);
      expect(t.now, Duration.zero);
    });

    test('two simultaneous downloads share 2 MiB/s over 10 seconds', () async {
      final t = VirtualTime();
      final l = RateLimiter(
        bytesPerSecond: 2 * mib,
        clock: t.clock,
        sleep: t.sleep,
      );
      var total = 0;
      var running = 2;
      const chunk = 16 * 1024;

      Future<void> download() async {
        while (t.now < const Duration(seconds: 10)) {
          await l.acquire(chunk);
          total += chunk;
        }
        running--;
      }

      unawaited(download());
      unawaited(download());
      await t.drain(() => running > 0);

      final rate =
          total / t.now.inMicroseconds * Duration.microsecondsPerSecond;
      expect(rate, inInclusiveRange(2 * mib * 0.9, 2 * mib * 1.1));
    });

    test('changing the limit while running takes effect', () async {
      final t = VirtualTime();
      final l = RateLimiter(
        bytesPerSecond: 1 * mib,
        clock: t.clock,
        sleep: t.sleep,
      );
      var total = 0;
      var done = false;
      const chunk = 16 * 1024;

      unawaited(() async {
        while (t.now < const Duration(seconds: 10)) {
          await l.acquire(chunk);
          total += chunk;
          if (t.now >= const Duration(seconds: 5) &&
              l.bytesPerSecond == 1 * mib) {
            l.bytesPerSecond = 4 * mib;
          }
        }
        done = true;
      }());
      await t.drain(() => !done);

      // 5 s at 1 MiB/s plus 5 s at 4 MiB/s is about 25 MiB.
      expect(total / mib, inInclusiveRange(22, 28));
    });

    test('setting the limit to zero releases waiters at once', () async {
      final t = VirtualTime();
      final l = RateLimiter(
        bytesPerSecond: 1024,
        clock: t.clock,
        sleep: t.sleep,
      );
      var released = false;
      unawaited(
        l.acquire(1024 * 1024).then((_) => released = true),
      ); // about 1000 s of debt
      await Future<void>.delayed(Duration.zero);
      expect(released, isFalse);
      l.bytesPerSecond = 0;
      await Future<void>.delayed(Duration.zero);
      expect(released, isTrue);
      expect(t.now, Duration.zero);
    });

    test('an idle bucket holds at most one second of the limit', () async {
      final t = VirtualTime();
      final l = RateLimiter(
        bytesPerSecond: 1 * mib,
        clock: t.clock,
        sleep: t.sleep,
      );
      t.now += const Duration(minutes: 5); // a long idle spell
      await l.acquire(1 * mib); // exactly one second's worth: free
      expect(t.now, const Duration(minutes: 5));
      final waiting = l.acquire(1 * mib);
      var done = false;
      unawaited(waiting.then((_) => done = true));
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse, reason: 'a second burst should have to wait');
    });
  });

  group('RateLimiter with real downloads', () {
    late Directory dir;
    late HttpClient client;
    late RangeServer server;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('limiter_');
      client = HttpClient()..maxConnectionsPerHost = 16;
    });
    tearDown(() async {
      client.close(force: true);
      await server.close();
      dir.deleteSync(recursive: true);
    });

    DownloadTask taskFor(String id, RateLimiter limiter) => DownloadTask(
      client: client,
      limiter: limiter,
      snapshot: DownloadSnapshot(
        request: DownloadRequest(
          id: id,
          url: server.url,
          saveDir: '${dir.path}/$id',
          maxConnections: 4,
        ),
      ),
    );

    test('two downloads at once stay within the shared limit', () async {
      server = await RangeServer.start(size: 3 * mib);
      final limiter = RateLimiter(bytesPerSecond: 4 * mib);
      final watch = Stopwatch()..start();
      final results = await Future.wait([
        taskFor('a', limiter).run(),
        taskFor('b', limiter).run(),
      ]);
      watch.stop();
      expect(
        results.every((r) => r.status == DownloadStatus.completed),
        isTrue,
      );

      // 6 MiB at 4 MiB/s needs about 1.5 s. Much faster means no limit.
      expect(watch.elapsedMilliseconds, greaterThan(1300));
      expect(watch.elapsedMilliseconds, lessThan(2600));
    });

    test('setting the limit to zero mid-download speeds it up', () async {
      server = await RangeServer.start(size: 4 * mib);
      final limiter = RateLimiter(bytesPerSecond: 256 * 1024); // 16 s alone
      final task = taskFor('a', limiter);
      final run = task.run();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      limiter.bytesPerSecond = 0;
      final watch = Stopwatch()..start();
      final result = await run;
      expect(result.status, DownloadStatus.completed);
      expect(watch.elapsedMilliseconds, lessThan(2500));
      expect(File('${dir.path}/a/file.bin').readAsBytesSync(), server.allBytes);
    });

    test('single-connection downloads obey the limit too', () async {
      server = await RangeServer.start(size: 1 * mib, noRanges: true);
      final limiter = RateLimiter(bytesPerSecond: 512 * 1024);
      final watch = Stopwatch()..start();
      final result = await taskFor('a', limiter).run();
      expect(result.status, DownloadStatus.completed);
      expect(watch.elapsedMilliseconds, greaterThan(1300));
    });
  });
}
