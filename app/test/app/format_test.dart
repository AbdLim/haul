import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/format.dart';

void main() {
  test('formatBytes', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(1536), '1.50 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.00 MB');
    expect(formatBytes(150 * 1024 * 1024), '150 MB');
  });

  test('formatEta', () {
    expect(formatEta(const Duration(seconds: 42)), '42s');
    expect(formatEta(const Duration(seconds: 125)), '2m 05s');
    expect(formatEta(const Duration(hours: 1, minutes: 2)), '1h 02m');
    expect(formatEta(const Duration(hours: 12, minutes: 40)), '12h 40m');
    expect(formatEta(Duration.zero), '0s');
  });
}
