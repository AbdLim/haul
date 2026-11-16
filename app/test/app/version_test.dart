import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/version.dart';

void main() {
  test('the version in the About pane is the one in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml has no version');
    expect(appVersion, match!.group(1));
  });

  test('the browser extension carries the same version', () {
    for (final name in ['chrome', 'firefox']) {
      final manifest = File('../extension/manifest.$name.json')
          .readAsStringSync();
      expect(manifest, contains('"version": "$appVersion"'), reason: name);
    }
  });

  test('the app icon set is the brand icon set', () {
    for (final size in [16, 32, 64, 128, 256, 512, 1024]) {
      final name = 'app_icon_$size.png';
      final brand = File('assets/brand/macos/AppIcon.appiconset/$name');
      final used = File(
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/$name',
      );
      expect(used.readAsBytesSync(), brand.readAsBytesSync(), reason: name);
    }
  });

  test('the macOS project names the app Haul with the right identity', () {
    final xcconfig = File('macos/Runner/Configs/AppInfo.xcconfig')
        .readAsStringSync();
    expect(xcconfig, contains('PRODUCT_NAME = Haul'));
    expect(xcconfig, contains('PRODUCT_BUNDLE_IDENTIFIER = dev.haul.app'));
    expect(
      xcconfig,
      contains('PRODUCT_COPYRIGHT = Copyright © 2026 Abdulalim Ladan'),
    );
    final plist = File('macos/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>CFBundleDisplayName</key>'));
  });

  test('the guide shown in About is bundled', () {
    final guide = File('assets/docs/GUIDE.md').readAsStringSync();
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/docs/'));
    for (final text in [
      'Copy token',
      'Test connection',
      'Download with Haul',
      'Retry',
      'New link',
    ]) {
      expect(guide, contains(text));
    }
  });

  test('the README names the real things a person has to find', () {
    final readme = File('../README.md').readAsStringSync();
    for (final text in [
      'Copy token',
      'Test connection',
      'Pairing token',
      'curl http://127.0.0.1:47821/v1/ping',
      'Haul did not answer',
      'haul-chrome-$appVersion.zip',
      'Haul-$appVersion.dmg',
    ]) {
      expect(readme, contains(text));
    }
  });
}
