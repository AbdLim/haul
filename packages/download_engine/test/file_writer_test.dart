import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('writer_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('create sets the file to the full size', () async {
    final w = await FileWriter.create('${dir.path}/a.part', 5000);
    await w.close();
    expect(File('${dir.path}/a.part').lengthSync(), 5000);
  });

  test('100 concurrent chunks at shuffled offsets land correctly', () async {
    const chunk = 1000;
    const count = 100;
    final expected = Uint8List(chunk * count);
    for (var i = 0; i < expected.length; i++) {
      expected[i] = (i * 7 + i ~/ 256) & 0xff;
    }
    final w = await FileWriter.create('${dir.path}/b.part', expected.length);

    final order = List.generate(count, (i) => i)..shuffle(Random(42));
    // Fire everything without awaiting in between, from "concurrent" callers.
    final futures = [
      for (final i in order)
        w.write(
          i * chunk,
          Uint8List.sublistView(expected, i * chunk, (i + 1) * chunk),
        ),
    ];
    await Future.wait(futures);
    await w.close();

    expect(File('${dir.path}/b.part').readAsBytesSync(), expected);
  });

  test('reopening does not truncate and still writes at any offset', () async {
    final path = '${dir.path}/c.part';
    final first = await FileWriter.create(path, 1000);
    await first.write(900, Uint8List.fromList(List.filled(100, 9)));
    await first.close();

    final second = await FileWriter.open(path);
    expect(await second.length(), 1000);
    await second.write(0, Uint8List.fromList(List.filled(10, 1)));
    await second.write(500, Uint8List.fromList(List.filled(10, 5)));
    await second.close();

    final bytes = File(path).readAsBytesSync();
    expect(bytes.length, 1000);
    expect(bytes.sublist(0, 10), List.filled(10, 1));
    expect(bytes.sublist(500, 510), List.filled(10, 5));
    expect(bytes.sublist(900), List.filled(100, 9)); // survived the reopen
  });

  test('writes apply in the order they were queued', () async {
    final w = await FileWriter.create('${dir.path}/d.part', 10);
    final a = w.write(0, Uint8List.fromList([1, 1, 1, 1]));
    final b = w.write(2, Uint8List.fromList([2, 2]));
    await Future.wait([a, b]);
    await w.close();
    expect(File('${dir.path}/d.part').readAsBytesSync().sublist(0, 4), [
      1,
      1,
      2,
      2,
    ]);
  });

  test('flush waits for queued writes', () async {
    final w = await FileWriter.create('${dir.path}/e.part', 100);
    unawaited(w.write(0, Uint8List.fromList([7])));
    await w.flush();
    expect(File('${dir.path}/e.part').readAsBytesSync()[0], 7);
    await w.close();
  });

  test('writing after close is an error and close is idempotent', () async {
    final w = await FileWriter.create('${dir.path}/f.part', 10);
    await w.close();
    await w.close();
    expect(() => w.write(0, Uint8List(1)), throwsStateError);
  });

  test('creating in a missing folder makes the folder', () async {
    final w = await FileWriter.create('${dir.path}/x/y/g.part', 10);
    await w.close();
    expect(File('${dir.path}/x/y/g.part').existsSync(), isTrue);
  });

  test('flushes interleaved with writes never overlap on the file', () async {
    // Regression: RandomAccessFile allows one async operation at a time, and
    // a flush used to start while a queued write was still running.
    final w = await FileWriter.create('${dir.path}/h.part', 64 * 1024);
    final futures = <Future<void>>[];
    for (var i = 0; i < 200; i++) {
      futures.add(
        w.write((i % 64) * 1024, Uint8List(1024)..fillRange(0, 1024, i)),
      );
      if (i % 7 == 0) futures.add(w.flush());
    }
    await Future.wait(futures);
    await w.close();
  });
}
