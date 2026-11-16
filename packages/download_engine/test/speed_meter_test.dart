import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

void main() {
  late Duration now;
  late SpeedMeter meter;
  setUp(() {
    now = Duration.zero;
    meter = SpeedMeter(clock: () => now);
  });

  void feed(int bytesPerSecond, int seconds) {
    for (var i = 0; i < seconds * 10; i++) {
      now += const Duration(milliseconds: 100);
      meter.add(bytesPerSecond ~/ 10);
    }
  }

  test('is zero before any data', () {
    expect(meter.bytesPerSecond, 0);
    expect(meter.eta(1000), isNull);
  });

  test('settles on the steady rate after a full window', () {
    feed(1000000, 8);
    expect(meter.bytesPerSecond, closeTo(1000000, 30000));
  });

  test('follows a change in rate within the window', () {
    feed(1000000, 6);
    feed(200000, 6);
    expect(meter.bytesPerSecond, closeTo(200000, 20000));
  });

  test('old data drops out of the 5-second window', () {
    feed(1000000, 5);
    now += const Duration(seconds: 6);
    expect(meter.bytesPerSecond, 0);
  });

  test('the first burst does not read as a spike', () {
    now += const Duration(milliseconds: 10);
    meter.add(1000000);
    expect(meter.bytesPerSecond, lessThanOrEqualTo(1000000));
  });

  test('ETA is remaining bytes over speed', () {
    feed(1000000, 8);
    final eta = meter.eta(10000000)!;
    expect(eta.inSeconds, inInclusiveRange(9, 11));
  });

  test('reset forgets everything', () {
    feed(1000000, 2);
    meter.reset();
    expect(meter.bytesPerSecond, 0);
  });
}
