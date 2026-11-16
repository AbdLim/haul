import 'package:download_engine/download_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/features/detail/segment_map_geometry.dart';

const mib = 1024 * 1024;

List<Segment> eight({int downloadedEach = 0}) => [
  for (var i = 0; i < 8; i++)
    Segment(
      id: i,
      start: i * 100,
      end: i * 100 + 99,
      downloaded: downloadedEach,
    ),
];

void main() {
  group('layoutBlocks', () {
    test('eight equal segments make eight equal blocks across the width', () {
      final blocks = layoutBlocks(eight(), 800);
      expect(blocks, hasLength(8));
      for (var i = 0; i < 8; i++) {
        expect(blocks[i].left, closeTo(i * 100, 0.001));
        expect(blocks[i].right, closeTo(i * 100 + 100, 0.001));
        expect(blocks[i].width, closeTo(100, 0.001));
      }
    });

    test('each block fills by how much of its own segment has arrived', () {
      final segments = eight();
      segments[0] = segments[0].copyWith(downloaded: 50);
      segments[1] = segments[1].copyWith(downloaded: 100);
      segments[2] = segments[2].copyWith(downloaded: 25);
      final blocks = layoutBlocks(segments, 800);
      expect(blocks[0].fill, 0.5);
      expect(blocks[1].fill, 1);
      expect(blocks[1].done, isTrue);
      expect(blocks[2].fill, 0.25);
      expect(blocks[3].fill, 0);
      expect(blocks.where((b) => b.done), hasLength(1));
    });

    test('blocks fill independently of one another', () {
      final segments = eight()
        ..[3] = const Segment(id: 3, start: 300, end: 399, downloaded: 80);
      final blocks = layoutBlocks(segments, 800);
      expect(blocks.map((b) => b.fill).toList(), [0, 0, 0, 0.8, 0, 0, 0, 0]);
    });

    test('blocks are in file order whatever order the segments come in', () {
      final blocks = layoutBlocks(eight().reversed.toList(), 800);
      expect(blocks.map((b) => b.id), [0, 1, 2, 3, 4, 5, 6, 7]);
    });

    test('unequal segments make unequal blocks', () {
      final blocks = layoutBlocks(const [
        Segment(id: 0, start: 0, end: 299),
        Segment(id: 1, start: 300, end: 399),
      ], 400);
      expect(blocks[0].width, closeTo(300, 0.001));
      expect(blocks[1].width, closeTo(100, 0.001));
    });

    test('nothing to draw gives nothing', () {
      expect(layoutBlocks(const [], 800), isEmpty);
      expect(layoutBlocks(eight(), 0), isEmpty);
    });

    test('fill is held between 0 and 1', () {
      final blocks = layoutBlocks(const [
        Segment(id: 0, start: 0, end: 99, downloaded: 500),
      ], 100);
      expect(blocks.single.fill, 1);
    });
  });

  group('lerpBlocks', () {
    final before = layoutBlocks(const [
      Segment(id: 0, start: 0, end: 399, downloaded: 100),
      Segment(id: 1, start: 400, end: 799),
    ], 800);
    // Segment 0 was split: it now ends at 199 and a new segment 2 takes the rest.
    final after = layoutBlocks(const [
      Segment(id: 0, start: 0, end: 199, downloaded: 100),
      Segment(id: 2, start: 200, end: 399),
      Segment(id: 1, start: 400, end: 799),
    ], 800);

    test('at the start it is the old picture and at the end the new one', () {
      final start = lerpBlocks(before, after, 0);
      final end = lerpBlocks(before, after, 1);
      expect(
        end.map((b) => (b.id, b.left, b.right)),
        after.map((b) => (b.id, b.left, b.right)),
      );
      final old0 = start.firstWhere((b) => b.id == 0);
      expect(
        old0.right,
        closeTo(400, 0.001),
        reason: 'still the whole old block',
      );
    });

    test(
      'the cut block shrinks while the new one grows out of its right end',
      () {
        final mid = lerpBlocks(before, after, 0.5);
        final cut = mid.firstWhere((b) => b.id == 0);
        final fresh = mid.firstWhere((b) => b.id == 2);
        expect(cut.right, closeTo(300, 0.001)); // halfway from 400 to 200
        expect(fresh.right, closeTo(400, 0.001));
        expect(fresh.left, closeTo(300, 0.001)); // halfway from 400 to 200
        expect(fresh.width, greaterThan(0));
        expect(fresh.width, lessThan(200));
      },
    );

    test('a new block starts with no width', () {
      final start = lerpBlocks(before, after, 0);
      expect(start.firstWhere((b) => b.id == 2).width, 0);
    });

    test('blocks that did not change stay put', () {
      for (final t in [0.0, 0.3, 1.0]) {
        final b = lerpBlocks(before, after, t).firstWhere((b) => b.id == 1);
        expect(b.left, closeTo(400, 0.001));
        expect(b.right, closeTo(800, 0.001));
      }
    });
  });

  group('gainedBlock', () {
    test('is true only when a segment appears', () {
      final a = layoutBlocks(eight(), 800);
      final b = layoutBlocks([
        ...eight(),
        const Segment(id: 8, start: 800, end: 899),
      ], 900);
      expect(gainedBlock(a, b), isTrue);
      expect(gainedBlock(a, a), isFalse);
      expect(gainedBlock(b, a), isFalse);
    });
  });

  group('ConnectionSpeeds', () {
    final t0 = DateTime.utc(2026, 5, 1, 12);

    List<Segment> at(int a, [int b = 0]) => [
      Segment(id: 0, start: 0, end: 100 * mib - 1, downloaded: a),
      Segment(id: 1, start: 100 * mib, end: 200 * mib - 1, downloaded: b),
    ];

    test('knows nothing at first', () {
      final s = ConnectionSpeeds();
      s.update(at(0), t0);
      expect(s.speedOf(0), 0);
      expect(s.speedOf(1), 0);
      expect(s.speedOf(99), 0);
    });

    test('works out each connection on its own', () {
      final s = ConnectionSpeeds()
        ..update(at(0, 0), t0)
        ..update(at(2 * mib, 1 * mib), t0.add(const Duration(seconds: 1)));
      expect(s.speedOf(0), closeTo(2 * mib, 1));
      expect(s.speedOf(1), closeTo(1 * mib, 1));
    });

    test('divides by the real time between events', () {
      final s = ConnectionSpeeds()
        ..update(at(0), t0)
        ..update(at(1 * mib), t0.add(const Duration(milliseconds: 250)));
      expect(s.speedOf(0), closeTo(4 * mib, 1));
    });

    test('smooths so the figure does not jump', () {
      final s = ConnectionSpeeds()..update(at(0), t0);
      var bytes = 0;
      var t = t0;
      for (var i = 0; i < 6; i++) {
        bytes += 4 * mib;
        t = t.add(const Duration(seconds: 1));
        s.update(at(bytes), t);
      }
      expect(s.speedOf(0), closeTo(4 * mib, 0.1 * mib));
      // One slow second only pulls it part of the way down.
      bytes += 0;
      t = t.add(const Duration(seconds: 1));
      s.update(at(bytes), t);
      expect(s.speedOf(0), inExclusiveRange(1.5 * mib, 3 * mib));
    });

    test('a segment that started over reads zero, not a negative speed', () {
      final s = ConnectionSpeeds()
        ..update(at(5 * mib), t0)
        ..update(at(1 * mib), t0.add(const Duration(seconds: 1)));
      expect(s.speedOf(0), greaterThanOrEqualTo(0));
    });

    test('a new connection from a split starts at zero', () {
      final s = ConnectionSpeeds()
        ..update(at(0), t0)
        ..update([
          ...at(1 * mib),
          const Segment(id: 2, start: 200 * mib, end: 300 * mib - 1),
        ], t0.add(const Duration(seconds: 1)));
      expect(s.speedOf(2), 0);
    });

    test('forgets connections that are gone', () {
      final s = ConnectionSpeeds()
        ..update(at(0, 0), t0)
        ..update(at(1 * mib, 1 * mib), t0.add(const Duration(seconds: 1)))
        ..update([at(2 * mib).first], t0.add(const Duration(seconds: 2)));
      expect(s.speedOf(1), 0);
    });

    test('clear starts again', () {
      final s = ConnectionSpeeds()
        ..update(at(0), t0)
        ..update(at(1 * mib), t0.add(const Duration(seconds: 1)));
      s.clear();
      expect(s.speedOf(0), 0);
    });
  });
}
