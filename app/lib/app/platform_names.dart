import 'package:flutter/foundation.dart';

/// What this platform calls the things Haul's copy mentions, so a Windows
/// person is not told to look in the Finder or press Command-N.
///
/// The platform is read from [defaultTargetPlatform], so tests can ask for
/// another one without changing the machine they run on.
abstract final class PlatformNames {
  static bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;

  /// The app that shows files: the Finder or File Explorer.
  static String get fileManager => _mac ? 'Finder' : 'File Explorer';

  /// Where a deleted file goes first: the Trash or the Recycle Bin.
  static String get trash => _mac ? 'Trash' : 'Recycle Bin';

  /// Where saved passwords are kept, as a sentence would say it.
  static String get credentialStore =>
      _mac ? 'your Keychain' : 'your Windows account';

  /// The key that runs a menu command, for a sentence.
  static String get commandKey => _mac ? 'Command' : 'Control';

  /// The same key, as a shortcut is written: ⌘ or Ctrl.
  static String get commandSymbol => _mac ? '⌘' : 'Ctrl';

  /// The computer itself: a Mac or a PC.
  static String get computer => _mac ? 'Mac' : 'PC';

  /// Where the icon lives when the window is hidden.
  static String get trayArea => _mac ? 'menu bar' : 'notification area';
}
