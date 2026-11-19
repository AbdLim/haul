import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import 'sound_player.dart';

/// Plays the Windows sounds people already know, the `wav` files in the
/// system's own media folder.
class WindowsSoundPlayer implements SoundPlayer {
  WindowsSoundPlayer({
    this.directory = r'C:\Windows\Media',
    Future<void> Function(String file)? play,
  }) : _play = play ?? playWav;

  final String directory;
  final Future<void> Function(String file) _play;
  bool _playing = false;

  @override
  Future<List<String>> names() async {
    final dir = Directory(directory);
    if (!dir.existsSync()) return const [];
    final out = [
      for (final f in dir.listSync())
        if (f is File && f.path.toLowerCase().endsWith('.wav'))
          p.basenameWithoutExtension(f.path),
    ]..sort();
    return out;
  }

  @override
  Future<bool> play(String name) async {
    // A name from outside is never trusted as a path.
    if (_playing || name != p.basename(name) || name.isEmpty) return false;
    final file = p.join(directory, '$name.wav');
    if (!File(file).existsSync()) return false;
    _playing = true;
    try {
      await _play(file);
      return true;
    } on Object {
      return false;
    } finally {
      _playing = false;
    }
  }
}

/// Plays [file] and returns when it has finished.
///
/// It runs on a throwaway isolate because Windows' player has no "still
/// playing" answer: the only way to know when a sound ends, and so when the
/// next one may start, is to wait for it, which would freeze the window.
Future<void> playWav(String file) => Isolate.run(() => playWavBlocking(file));

/// The blocking call, for use off the main isolate.
void playWavBlocking(String file) {
  final playSound = DynamicLibrary.open('winmm.dll')
      .lookupFunction<
        Int32 Function(Pointer<Utf16>, IntPtr, Uint32),
        int Function(Pointer<Utf16>, int, int)
      >('PlaySoundW');
  final name = file.toNativeUtf16();
  try {
    // SND_FILENAME | SND_NODEFAULT: the file itself, and silence rather than
    // the default beep if it is unreadable.
    playSound(name, 0, _fromFile | _noDefault);
  } finally {
    calloc.free(name);
  }
}

const _fromFile = 0x00020000;
const _noDefault = 0x00000002;
