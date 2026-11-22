import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haul/services/system/windows_sound_player.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('windows_sounds_');
    for (final n in ['Pop', 'Glass', 'Hero']) {
      File('${dir.path}/$n.wav').writeAsBytesSync([0]);
    }
    File('${dir.path}/readme.txt').writeAsStringSync('x');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('lists the wav sounds by name, sorted', () async {
    final p = WindowsSoundPlayer(directory: dir.path, play: (_) async {});
    expect(await p.names(), ['Glass', 'Hero', 'Pop']);
  });

  test('a missing folder lists nothing', () async {
    final p = WindowsSoundPlayer(directory: '${dir.path}/nope');
    expect(await p.names(), isEmpty);
  });

  test('plays the file for the name', () async {
    final played = <String>[];
    final p = WindowsSoundPlayer(
      directory: dir.path,
      play: (f) async => played.add(f),
    );
    expect(await p.play('Glass'), isTrue);
    expect(played, [path.join(dir.path, 'Glass.wav')]);
  });

  test('a second sound while one plays is dropped, not queued', () async {
    final gate = Completer<void>();
    final played = <String>[];
    final p = WindowsSoundPlayer(
      directory: dir.path,
      play: (f) {
        played.add(f);
        return gate.future;
      },
    );
    final first = p.play('Glass');
    expect(await p.play('Hero'), isFalse);
    gate.complete();
    expect(await first, isTrue);
    expect(played, [path.join(dir.path, 'Glass.wav')]);
    // Once it has finished, the next one plays.
    expect(await p.play('Hero'), isTrue);
  });

  test('a name that is not a plain file name is refused', () async {
    final played = <String>[];
    final p = WindowsSoundPlayer(
      directory: dir.path,
      play: (f) async => played.add(f),
    );
    expect(await p.play('../Glass'), isFalse);
    expect(await p.play(''), isFalse);
    expect(await p.play('Missing'), isFalse);
    expect(played, isEmpty);
  });

  test('a player that fails reports false and can be used again', () async {
    var fail = true;
    final p = WindowsSoundPlayer(
      directory: dir.path,
      play: (_) async {
        if (fail) throw StateError('no sound');
      },
    );
    expect(await p.play('Glass'), isFalse);
    fail = false;
    expect(await p.play('Glass'), isTrue);
  });

  test('without a folder it uses the sounds in the system folder', () {
    final p = WindowsSoundPlayer();
    final root = Platform.environment['SystemRoot'];
    expect(
      p.directory,
      path.join(
        root == null || root.isEmpty ? r'C:\Windows' : root,
        'Media',
      ),
    );
  });
}
