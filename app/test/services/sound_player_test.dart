import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haul/services/system/sound_player.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('sounds_');
    for (final n in ['Pop', 'Glass', 'Hero']) {
      File('${dir.path}/$n.aiff').writeAsBytesSync([0]);
    }
    File('${dir.path}/readme.txt').writeAsStringSync('x');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('lists the aiff sounds by name, sorted', () async {
    final p = AfplaySoundPlayer(directory: dir.path, run: (_) async {});
    expect(await p.names(), ['Glass', 'Hero', 'Pop']);
  });

  test('a missing folder lists nothing', () async {
    final p = AfplaySoundPlayer(directory: '${dir.path}/nope');
    expect(await p.names(), isEmpty);
  });

  test('plays the file for the name', () async {
    final played = <String>[];
    final p = AfplaySoundPlayer(
      directory: dir.path,
      run: (f) async => played.add(f),
    );
    expect(await p.play('Glass'), isTrue);
    expect(played, [path.join(dir.path, 'Glass.aiff')]);
  });

  test('a second sound while one plays is dropped, not queued', () async {
    final gate = Completer<void>();
    final played = <String>[];
    final p = AfplaySoundPlayer(
      directory: dir.path,
      run: (f) {
        played.add(f);
        return gate.future;
      },
    );
    final first = p.play('Glass');
    expect(await p.play('Hero'), isFalse);
    gate.complete();
    expect(await first, isTrue);
    expect(played, [path.join(dir.path, 'Glass.aiff')]);
    // Once it has finished, the next one plays.
    expect(await p.play('Hero'), isTrue);
  });

  test('a name that is not a plain file name is refused', () async {
    final played = <String>[];
    final p = AfplaySoundPlayer(
      directory: dir.path,
      run: (f) async => played.add(f),
    );
    expect(await p.play('../Glass'), isFalse);
    expect(await p.play(''), isFalse);
    expect(await p.play('Missing'), isFalse);
    expect(played, isEmpty);
  });

  test('a player that fails reports false and can be used again', () async {
    var fail = true;
    final p = AfplaySoundPlayer(
      directory: dir.path,
      run: (_) async {
        if (fail) throw const ProcessException('afplay', []);
      },
    );
    expect(await p.play('Glass'), isFalse);
    fail = false;
    expect(await p.play('Glass'), isTrue);
  });
}
