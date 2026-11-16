import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

const mib = 1024 * 1024;

/// Segments must tile [0, size) with no gaps and no overlaps.
void expectExactCover(List<Segment> segments, int size) {
  final sorted = [...segments]..sort((a, b) => a.start.compareTo(b.start));
  expect(sorted.first.start, 0);
  expect(sorted.last.end, size - 1);
  for (var i = 1; i < sorted.length; i++) {
    expect(
      sorted[i].start,
      sorted[i - 1].end + 1,
      reason: 'gap or overlap at $i',
    );
  }
  expect(sorted.fold<int>(0, (n, s) => n + s.length), size);
}

void main() {
  group('planSegments', () {
    for (final size in [1, mib - 1, mib, 10 * mib, 1024 * mib + 7]) {
      test('covers $size bytes exactly', () {
        final segments = planSegments(size, 8);
        expectExactCover(segments, size);
        expect(
          segments.map((s) => s.id),
          List.generate(segments.length, (i) => i),
        );
      });
    }

    test('count is floor(size / 1 MiB) clamped to the connection limit', () {
      expect(planSegments(1, 8), hasLength(1));
      expect(planSegments(mib - 1, 8), hasLength(1));
      expect(planSegments(3 * mib + 5, 8), hasLength(3));
      expect(planSegments(10 * mib, 8), hasLength(8));
      expect(planSegments(10 * mib, 16), hasLength(10));
      expect(planSegments(1024 * mib, 16), hasLength(16));
      expect(planSegments(10 * mib, 1), hasLength(1));
    });

    test('segments are equal except the last, which takes the remainder', () {
      final s = planSegments(10 * mib + 3, 4);
      expect(s[0].length, s[1].length);
      expect(s[1].length, s[2].length);
      expect(s.last.length, s[0].length + (10 * mib + 3) % 4);
    });

    test('new segments are pending with nothing downloaded', () {
      for (final s in planSegments(5 * mib, 4)) {
        expect(s.status, SegmentStatus.pending);
        expect(s.downloaded, 0);
      }
    });

    test('an empty file has no segments', () {
      expect(planSegments(0, 8), isEmpty);
    });
  });

  group('splitLargest', () {
    List<Segment> active(List<Segment> list) => [
      for (final s in list) s.copyWith(status: SegmentStatus.active),
    ];

    test('splits the segment with the most left, keeping coverage', () {
      const size = 40 * mib;
      final segments = active(planSegments(size, 4));
      segments[1] = segments[1].copyWith(downloaded: 8 * mib);
      final result = splitLargest(segments)!;

      expectExactCover(result.segments, size);
      expect(result.segments, hasLength(5));
      // Segment 1 has the least left, so it must not have been the victim.
      expect(result.segments[1].end, segments[1].end);
      expect(result.created.status, SegmentStatus.active);
      expect(result.created.id, 4);
    });

    test('the new segment starts halfway through what remains', () {
      final segments = active([
        const Segment(id: 0, start: 0, end: 20 * mib - 1, downloaded: 4 * mib),
      ]);
      final r = splitLargest(segments)!;
      // 16 MiB left from byte 4 MiB; split at 4 + 8 = 12 MiB.
      expect(r.created.start, 12 * mib);
      expect(r.created.end, 20 * mib - 1);
      expect(r.segments.first.end, 12 * mib - 1);
      expect(r.created.downloaded, 0);
      expectExactCover(r.segments, 20 * mib);
    });

    test('does not split a segment with 2 MiB or less left', () {
      final segments = active([
        const Segment(id: 0, start: 0, end: 10 * mib - 1, downloaded: 8 * mib),
      ]);
      expect(splitLargest(segments), isNull);
    });

    test('splits at just over 2 MiB', () {
      final segments = active([
        const Segment(id: 0, start: 0, end: 4 * mib, downloaded: 2 * mib - 1),
      ]);
      expect(splitLargest(segments), isNotNull);
    });

    test('only active segments are candidates', () {
      final segments = [
        const Segment(id: 0, start: 0, end: 20 * mib - 1),
        const Segment(
          id: 1,
          start: 20 * mib,
          end: 40 * mib - 1,
          status: SegmentStatus.done,
          downloaded: 20 * mib,
        ),
      ];
      expect(splitLargest(segments), isNull); // 0 is pending, 1 is done
    });

    test('repeated splits keep total coverage', () {
      const size = 64 * mib;
      var segments = active(planSegments(size, 2));
      for (var i = 0; i < 5; i++) {
        final r = splitLargest(segments);
        if (r == null) break;
        segments = r.segments;
        expectExactCover(segments, size);
      }
      expect(segments.length, greaterThan(2));
      expect(segments.map((s) => s.id).toSet(), hasLength(segments.length));
    });
  });
}
