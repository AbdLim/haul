import 'package:flutter_test/flutter_test.dart';
import 'package:haul/services/system/windows_app_window.dart';

void main() {
  group('starting from the login item', () {
    test('--hidden anywhere in the command line starts hidden', () {
      expect(
        startedHiddenFromCommandLine(r'"C:\Program Files\Haul\haul.exe"'),
        isFalse,
      );
      expect(
        startedHiddenFromCommandLine(
          r'"C:\Program Files\Haul\haul.exe" --hidden',
        ),
        isTrue,
      );
      expect(startedHiddenFromCommandLine(r'haul.exe --hidden'), isTrue);
    });

    test('only the whole argument counts', () {
      expect(startedHiddenFromCommandLine('haul.exe --hidden=1'), isFalse);
      expect(startedHiddenFromCommandLine('haul.exe --hidden-now'), isFalse);
      expect(startedHiddenFromCommandLine('haul.exe --not-hidden'), isFalse);
      expect(startedHiddenFromCommandLine('haul.exe'), isFalse);
    });
  });
}
