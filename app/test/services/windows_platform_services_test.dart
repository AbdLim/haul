import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haul/services/system/windows_platform_services.dart';

/// A `Process.run` that records the call and reports success.
class _Runner {
  final calls = <(String, List<String>)>[];

  Future<ProcessResult> run(String executable, List<String> arguments) async {
    calls.add((executable, arguments));
    return ProcessResult(0, 0, '', '');
  }

  List<String> get last => calls.last.$2;
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('windows_services_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('Explorer is asked to select the path, in one argument', () async {
    final runner = _Runner();
    final platform = WindowsPlatformServices(run: runner.run);
    await platform.revealInFileManager(r'C:\Users\me\movie.mp4');
    expect(runner.calls.single.$1, 'explorer.exe');
    expect(runner.last, [r'/select,C:\Users\me\movie.mp4']);
  });

  test('a file or link opens through the shell handler', () async {
    final runner = _Runner();
    final platform = WindowsPlatformServices(run: runner.run);
    await platform.openFile(r'C:\Users\me\movie.mp4');
    await platform.openUrl('https://example.com/a');
    expect(runner.calls.map((c) => c.$1), everyElement('rundll32.exe'));
    expect(runner.calls[0].$2, [
      'url.dll,FileProtocolHandler',
      r'C:\Users\me\movie.mp4',
    ]);
    expect(runner.calls[1].$2, [
      'url.dll,FileProtocolHandler',
      'https://example.com/a',
    ]);
  });

  test('a link that is not http or https is not opened', () async {
    final runner = _Runner();
    final platform = WindowsPlatformServices(run: runner.run);
    await platform.openUrl('file:///C:/secret.txt');
    await platform.openUrl('nonsense');
    expect(runner.calls, isEmpty);
  });

  test('a missing file is not sent anywhere', () async {
    final runner = _Runner();
    final platform = WindowsPlatformServices(run: runner.run);
    await platform.moveToTrash('${dir.path}/nothing.bin');
    expect(runner.calls, isEmpty);
  });

  test('a file goes through PowerShell to the Recycle Bin, and so does a '
      'folder', () async {
    final runner = _Runner();
    final platform = WindowsPlatformServices(run: runner.run);
    final file = File('${dir.path}/movie.mp4')..writeAsStringSync('x');
    final folder = Directory('${dir.path}/season')..createSync();

    await platform.moveToTrash(file.path);
    await platform.moveToTrash(folder.path);

    expect(runner.calls.map((c) => c.$1), everyElement('powershell.exe'));
    expect(runner.last.sublist(0, 3), [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
    ]);
    expect(runner.calls[0].$2.last, contains('DeleteFile('));
    expect(runner.calls[1].$2.last, contains('DeleteDirectory('));
    expect(runner.calls[0].$2.last, contains('SendToRecycleBin'));
  });

  group('the Recycle Bin script', () {
    test('deletes a file, quietly, to the Recycle Bin', () {
      expect(
        recycleBinScript(r'C:\Users\me\a.zip', directory: false),
        'Add-Type -AssemblyName Microsoft.VisualBasic; '
        '[Microsoft.VisualBasic.FileIO.FileSystem]::'
        "DeleteFile('C:\\Users\\me\\a.zip','OnlyErrorDialogs',"
        "'SendToRecycleBin')",
      );
    });

    test('uses DeleteDirectory for a folder', () {
      expect(
        recycleBinScript(r'C:\Users\me\season', directory: true),
        contains(r"DeleteDirectory('C:\Users\me\season'"),
      );
    });

    test('a quote in the path is doubled for PowerShell', () {
      expect(
        recycleBinScript(r"C:\Users\O'Brien\a.zip", directory: false),
        contains(r"'C:\Users\O''Brien\a.zip'"),
      );
    });
  });
}
