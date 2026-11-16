import 'dart:io';

import 'macos_platform_services.dart';

/// Everything Haul needs from the host OS that Dart can't do portably.
///
/// The core engine never imports `dart:io` platform checks or plugins
/// directly; it only talks to this interface. Adding Windows or Linux
/// means writing one implementation of this class and returning it
/// from [PlatformServices.current].
abstract class PlatformServices {
  const PlatformServices();

  /// Where completed downloads go unless the user picks another folder.
  Future<Directory> defaultDownloadDirectory();

  /// Where Haul keeps its own state (queue database, partial files).
  Future<Directory> appSupportDirectory();

  /// Shows [path] in the OS file manager (Finder, Explorer, ...).
  Future<void> revealInFileManager(String path);

  /// Opens [path] with the default application.
  Future<void> openFile(String path);

  /// Moves [path] to the Trash (or Recycle Bin), so it can be got back.
  Future<void> moveToTrash(String path);

  /// Resolves the implementation for the running OS.
  static PlatformServices get current {
    if (Platform.isMacOS) return const MacOSPlatformServices();
    // Windows and Linux implementations land here later.
    throw UnsupportedError(
      'Haul does not support ${Platform.operatingSystem} yet.',
    );
  }
}
