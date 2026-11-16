import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Space Grotesk and its licence are bundled, weights 500 and 700', () {
    expect(File('assets/fonts/SpaceGrotesk-Variable.ttf').existsSync(), isTrue);
    expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: SpaceGrotesk'));
    expect(pubspec, contains('weight: 500'));
    expect(pubspec, contains('weight: 700'));
  });

  test('the font is never fetched at run time', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('google_fonts'), isFalse);
  });

  test('the Material icon font is not bundled', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('uses-material-design: false'),
    );
  });

  test('the brand files the app uses are present', () {
    for (final f in [
      'assets/brand/in-app/haul-mark-on-dark-256.png',
      'assets/brand/in-app/haul-mark-on-light-256.png',
      'assets/brand/menubar/haulMenubarTemplate.png',
      'assets/brand/menubar/haulMenubarTemplate@2x.png',
      'assets/brand/menubar/haulMenubarTemplate@3x.png',
      'assets/brand/svg/haul-mark-mono.svg',
    ]) {
      expect(File(f).existsSync(), isTrue, reason: f);
    }
  });

  test('the Phosphor regular font and its licence are bundled', () {
    expect(File('assets/fonts/Phosphor-Regular.ttf').existsSync(), isTrue);
    expect(File('assets/fonts/PHOSPHOR-LICENSE.txt').existsSync(), isTrue);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: PhosphorRegular'));
    // The package that normally supplies it does not compile on current Flutter.
    expect(pubspec.contains('phosphor_flutter:'), isFalse);
  });
}
