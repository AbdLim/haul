import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

import 'windows_login_item.dart';

/// Starting the app when the person logs in.
abstract class LoginItem {
  Future<bool> isEnabled();
  Future<void> setEnabled(bool enabled);

  static LoginItem get current {
    if (Platform.isMacOS) return LaunchAtStartupLoginItem();
    if (Platform.isWindows) return WindowsLoginItem();
    throw UnsupportedError('No login item for ${Platform.operatingSystem}');
  }
}

class LaunchAtStartupLoginItem implements LoginItem {
  LaunchAtStartupLoginItem() {
    LaunchAtStartup.instance.setup(
      // The label of the launch agent; the app also looks for it to know it
      // was started at login (see HaulWindowBridge.swift).
      appName: 'dev.haul.app',
      appPath: Platform.resolvedExecutable,
    );
  }

  @override
  Future<bool> isEnabled() => LaunchAtStartup.instance.isEnabled();

  @override
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await LaunchAtStartup.instance.enable();
    } else {
      await LaunchAtStartup.instance.disable();
    }
  }
}

class FakeLoginItem implements LoginItem {
  bool enabled = false;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async => enabled = value;
}
