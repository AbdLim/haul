import 'package:flutter_test/flutter_test.dart';
import 'package:haul/services/system/windows_sleep_blocker.dart';

void main() {
  test(
    'it asks for no sleep while a download runs, and lets go after',
    () async {
      final flags = <int>[];
      final blocker = WindowsSleepBlocker(
        setState: (f) {
          flags.add(f);
          return 1;
        },
      );

      await blocker.hold();
      expect(blocker.holding, isTrue);
      expect(flags, [0x80000001]);

      // Holding again changes nothing.
      await blocker.hold();
      expect(flags, hasLength(1));

      await blocker.release();
      expect(blocker.holding, isFalse);
      expect(flags.last, 0x80000000);

      // Releasing again changes nothing.
      await blocker.release();
      expect(flags, hasLength(2));
    },
  );

  test('if Windows refuses, it does not claim to be holding', () async {
    final flags = <int>[];
    final blocker = WindowsSleepBlocker(
      setState: (f) {
        flags.add(f);
        return 0;
      },
    );

    await blocker.hold();
    expect(blocker.holding, isFalse);
    await blocker.release();
    expect(flags, [0x80000001], reason: 'nothing to let go of');
  });
}
