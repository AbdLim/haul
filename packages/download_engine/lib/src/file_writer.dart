import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'models/download_error.dart';

/// The single owner of a download's `.part` file.
///
/// Workers hand it `(offset, bytes)` and it performs the writes one at a
/// time, so concurrent callers can never interleave a seek with another
/// caller's write.
class FileWriter {
  FileWriter._(this.path, this._file);

  final String path;
  final RandomAccessFile _file;
  Future<void> _tail = Future.value();
  Object? _failure;
  bool _closed = false;

  /// Creates (or replaces) the file and sets its length to [size].
  static Future<FileWriter> create(String path, int size) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    // `write` truncates, which is what we want for a brand-new file.
    final fresh = await file.open(mode: FileMode.write);
    try {
      await fresh.truncate(size);
    } on FileSystemException catch (e) {
      await fresh.close();
      throw _translate(e);
    }
    await fresh.close();
    return open(path);
  }

  /// Opens an existing file without touching its contents.
  ///
  /// `FileMode.append` is the one mode that neither truncates nor refuses
  /// `setPosition`; on macOS it still allows writes at arbitrary offsets
  /// (see `test/file_writer_test.dart`).
  static Future<FileWriter> open(String path) async {
    final raf = await File(path).open(mode: FileMode.append);
    return FileWriter._(path, raf);
  }

  Future<int> length() => _file.length();

  /// Runs [op] after everything already queued. `RandomAccessFile` allows
  /// only one asynchronous operation at a time, so every operation, writes
  /// and flushes alike, goes through this chain.
  Future<T> _enqueue<T>(Future<T> Function() op) {
    final done = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        done.complete(await op());
      } on Object catch (e) {
        done.completeError(e);
      }
    });
    return done.future;
  }

  /// Queues a write. The returned future completes when the bytes have been
  /// handed to the OS. Throws [DownloadError] (`diskFull`) when the disk is
  /// full; after any failure, every later write fails the same way.
  Future<void> write(int offset, Uint8List bytes) {
    if (_closed) return Future.error(StateError('FileWriter is closed'));
    return _enqueue(() async {
      final failure = _failure;
      if (failure != null) throw failure;
      try {
        await _file.setPosition(offset);
        await _file.writeFrom(bytes);
      } on FileSystemException catch (e) {
        final error = _translate(e);
        _failure = error;
        throw error;
      }
    });
  }

  /// Waits for queued writes, then asks the OS to persist them.
  Future<void> flush() {
    if (_closed) return Future.value();
    return _enqueue(() => _file.flush());
  }

  /// Flushes and closes. Safe to call twice.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _enqueue(() async {
      await _file.flush();
      await _file.close();
    });
  }

  static Object _translate(FileSystemException e) {
    // ENOSPC is 28 on macOS and Linux.
    if (e.osError?.errorCode == 28) {
      return const DownloadError(
        DownloadErrorCode.diskFull,
        'The disk is full',
      );
    }
    return DownloadError(
      DownloadErrorCode.unknown,
      'Could not write the file: ${e.osError?.message ?? e.message}',
    );
  }
}
