import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haul/services/system/windows_login_item.dart';

/// A `reg.exe` that records its arguments and reports what the test says.
class _Reg {
  _Reg(this.exitCode);

  int exitCode;
  final calls = <List<String>>[];

  Future<ProcessResult> run(List<String> arguments) async {
    calls.add(arguments);
    return ProcessResult(0, exitCode, '', '');
  }
}

void main() {
  test('the login command quotes the path and asks for no window', () {
    expect(
      loginCommand(r'C:\Program Files\Haul\haul.exe'),
      r'"C:\Program Files\Haul\haul.exe" --hidden',
    );
  });

  test('it is enabled when the Run key has an entry', () async {
    final reg = _Reg(0);
    final item = WindowsLoginItem(
      executable: r'C:\Haul\haul.exe',
      run: reg.run,
    );
    expect(await item.isEnabled(), isTrue);
    expect(reg.calls.single, ['query', runKey, '/v', runKeyValue]);

    final missing = _Reg(1);
    expect(
      await WindowsLoginItem(
        executable: r'C:\Haul\haul.exe',
        run: missing.run,
      ).isEnabled(),
      isFalse,
    );
  });

  test('switching it on writes the command to the Run key', () async {
    final reg = _Reg(0);
    final item = WindowsLoginItem(
      executable: r'C:\Haul\haul.exe',
      run: reg.run,
    );
    await item.setEnabled(true);
    expect(reg.calls.single, [
      'add',
      runKey,
      '/v',
      runKeyValue,
      '/t',
      'REG_SZ',
      '/d',
      r'"C:\Haul\haul.exe" --hidden',
      '/f',
    ]);
  });

  test('switching it off deletes the entry, quietly', () async {
    final reg = _Reg(0);
    final item = WindowsLoginItem(
      executable: r'C:\Haul\haul.exe',
      run: reg.run,
    );
    await item.setEnabled(false);
    expect(reg.calls.single, ['delete', runKey, '/v', runKeyValue, '/f']);
  });

  test('the Run key is under the current user, not the machine', () {
    expect(runKey, startsWith(r'HKEY_CURRENT_USER'));
  });
}
