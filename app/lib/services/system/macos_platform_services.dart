import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'platform_services.dart';

class MacOSPlatformServices extends PlatformServices {
  const MacOSPlatformServices({this.trashDirectory});

  /// Where trashed files go. Defaults to the user's `~/.Trash`; tests point
  /// it somewhere else.
  final Directory? trashDirectory;

  @override
  Future<Directory> defaultDownloadDirectory() async {
    final dir = await getDownloadsDirectory();
    if (dir != null) return dir;
    final home = Platform.environment['HOME']!;
    return Directory(p.join(home, 'Downloads'));
  }

  @override
  Future<Directory> appSupportDirectory() async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, 'Haul')).create(recursive: true);
  }

  @override
  Future<void> revealInFileManager(String path) async {
    await Process.run('open', ['-R', path]);
  }

  @override
  Future<void> openFile(String path) async {
    await Process.run('open', [path]);
  }

  @override
  Future<void> moveToTrash(String path) async {
    final entity =
        FileSystemEntity.typeSync(path) == FileSystemEntityType.directory
        ? Directory(path)
        : File(path);
    if (!entity.existsSync()) return;
    final trash =
        trashDirectory ??
        Directory(p.join(Platform.environment['HOME']!, '.Trash'));
    trash.createSync(recursive: true);

    // Never overwrite something already in the Trash: number the name.
    final name = p.basename(path);
    var target = p.join(trash.path, name);
    for (
      var i = 2;
      FileSystemEntity.typeSync(target) != FileSystemEntityType.notFound;
      i++
    ) {
      target = p.join(
        trash.path,
        '${p.basenameWithoutExtension(name)} $i${p.extension(name)}',
      );
    }
    try {
      await entity.rename(target);
    } on FileSystemException {
      // The file is on another volume, which cannot be renamed across.
      // Ask Finder to do it; it knows each volume's own Trash.
      final escaped = path.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      await Process.run('osascript', [
        '-e',
        'tell application "Finder" to delete POSIX file "$escaped"',
      ]);
    }
  }
}
