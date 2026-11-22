import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'platform_services.dart';

typedef CommandRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// The Windows way of doing the things in [PlatformServices]: Explorer to
/// show and open files, and PowerShell for the Recycle Bin (there is no
/// command-line switch that puts a file there).
class WindowsPlatformServices extends PlatformServices {
  WindowsPlatformServices({CommandRunner? run}) : _run = run ?? Process.run;

  final CommandRunner _run;

  @override
  Future<Directory> defaultDownloadDirectory() async {
    final dir = await getDownloadsDirectory();
    if (dir != null) return dir;
    final profile = Platform.environment['USERPROFILE']!;
    return Directory(p.join(profile, 'Downloads'));
  }

  @override
  Future<Directory> appSupportDirectory() async {
    // Windows builds this from the app's company and product names
    // (`%APPDATA%\dev.haul\Haul`), so it already ends in Haul.
    final base = await getApplicationSupportDirectory();
    return base.create(recursive: true);
  }

  @override
  Future<void> revealInFileManager(String path) async {
    // Explorer wants the path in the same argument as the switch.
    await _run('explorer.exe', ['/select,$path']);
  }

  @override
  Future<void> openFile(String path) async => _openWithShell(path);

  @override
  Future<void> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;
    await _openWithShell(uri.toString());
  }

  /// The same handler Explorer uses for double-clicks, so files open in their
  /// own application and links in the default browser.
  ///
  /// `Process.run` alone cannot do this: it starts the file itself, which is
  /// not an executable.
  Future<void> _openWithShell(String target) async {
    await _run('rundll32.exe', ['url.dll,FileProtocolHandler', target]);
  }

  @override
  Future<void> moveToTrash(String path) async {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.notFound) return;
    await _run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      recycleBinScript(path, directory: type == FileSystemEntityType.directory),
    ]);
  }
}

/// The PowerShell that sends [path] to the Recycle Bin, where it can still be
/// got back.
String recycleBinScript(String path, {required bool directory}) {
  // PowerShell reads a doubled quote inside single quotes as one quote.
  final quoted = path.replaceAll("'", "''");
  final delete = directory ? 'DeleteDirectory' : 'DeleteFile';
  return 'Add-Type -AssemblyName Microsoft.VisualBasic; '
      '[Microsoft.VisualBasic.FileIO.FileSystem]::'
      "$delete('$quoted','OnlyErrorDialogs','SendToRecycleBin')";
}
