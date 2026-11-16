import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Plays short sounds for events (a download finished, one failed).
abstract class SoundPlayer {
  /// The names that can be chosen, such as `Glass`, in a stable order.
  Future<List<String>> names();

  /// Plays [name]. A sound that is already playing is never talked over: the
  /// new one is dropped and false is returned.
  Future<bool> play(String name);
}

/// Plays the Mac's own alert sounds by running `afplay` on a file in
/// `/System/Library/Sounds`.
class AfplaySoundPlayer implements SoundPlayer {
  AfplaySoundPlayer({
    this.directory = '/System/Library/Sounds',
    Future<void> Function(String file)? run,
  }) : _run = run ?? _afplay;

  final String directory;
  final Future<void> Function(String file) _run;
  bool _playing = false;

  static Future<void> _afplay(String file) async {
    await Process.run('afplay', [file]);
  }

  @override
  Future<List<String>> names() async {
    final dir = Directory(directory);
    if (!dir.existsSync()) return const [];
    final out = [
      for (final f in dir.listSync())
        if (f is File && f.path.toLowerCase().endsWith('.aiff'))
          p.basenameWithoutExtension(f.path),
    ]..sort();
    return out;
  }

  @override
  Future<bool> play(String name) async {
    // A name from outside is never trusted as a path.
    if (_playing || name != p.basename(name) || name.isEmpty) return false;
    final file = p.join(directory, '$name.aiff');
    if (!File(file).existsSync()) return false;
    _playing = true;
    try {
      await _run(file);
      return true;
    } on Object {
      return false;
    } finally {
      _playing = false;
    }
  }
}
