import 'dart:io';

import 'login_item.dart';

typedef RegistryRunner = Future<ProcessResult> Function(List<String> arguments);

/// Where Windows keeps the list of programs to start at login.
const runKey =
    r'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run';

/// The name Haul's entry has in that list.
const runKeyValue = 'Haul';

/// Starts Haul from the `Run` key, which is the list Task Manager's Startup
/// tab shows. `--hidden` keeps it in the notification area, out of the way.
class WindowsLoginItem implements LoginItem {
  WindowsLoginItem({String? executable, RegistryRunner? run})
    : _executable = executable ?? Platform.resolvedExecutable,
      _run = run ?? _reg;

  final String _executable;
  final RegistryRunner _run;

  static Future<ProcessResult> _reg(List<String> arguments) =>
      Process.run('reg.exe', arguments);

  @override
  Future<bool> isEnabled() async {
    final result = await _run(['query', runKey, '/v', runKeyValue]);
    return result.exitCode == 0;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await _run([
        'add',
        runKey,
        '/v',
        runKeyValue,
        '/t',
        'REG_SZ',
        '/d',
        loginCommand(_executable),
        '/f',
      ]);
    } else {
      // Nothing to delete is not a failure.
      await _run(['delete', runKey, '/v', runKeyValue, '/f']);
    }
  }
}

/// The command line Windows runs at login. The quotes keep a path with spaces
/// in it one argument.
String loginCommand(String executable) => '"$executable" --hidden';
