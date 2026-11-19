import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/platform_names.dart';

void main() {
  void on(TargetPlatform platform, void Function() body) {
    debugDefaultTargetPlatformOverride = platform;
    try {
      body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  test('a Mac is told about the Finder, the Trash and Command', () {
    on(TargetPlatform.macOS, () {
      expect(PlatformNames.fileManager, 'Finder');
      expect(PlatformNames.trash, 'Trash');
      expect(PlatformNames.commandKey, 'Command');
      expect(PlatformNames.commandSymbol, '⌘');
      expect(PlatformNames.computer, 'Mac');
      expect(PlatformNames.trayArea, 'menu bar');
      expect(PlatformNames.credentialStore, 'your Keychain');
    });
  });

  test('a PC is told about Explorer, the Recycle Bin and Control', () {
    on(TargetPlatform.windows, () {
      expect(PlatformNames.fileManager, 'File Explorer');
      expect(PlatformNames.trash, 'Recycle Bin');
      expect(PlatformNames.commandKey, 'Control');
      expect(PlatformNames.commandSymbol, 'Ctrl');
      expect(PlatformNames.computer, 'PC');
      expect(PlatformNames.trayArea, 'notification area');
      expect(PlatformNames.credentialStore, 'your Windows account');
    });
  });
}
