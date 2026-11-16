import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/cubits/throughput_cubit.dart';
import 'package:haul/features/header/graph_geometry.dart';

const size = Size(600, 120);

List<double> flat(double v) => List<double>.filled(throughputSamples, v);

void main() {
  group('scale', () {
    test('never drops below the floor, so an idle line sits flat', () {
      expect(GraphGeometry.scaleFor(flat(0)), GraphGeometry.minScale);
      expect(GraphGeometry.scaleFor(flat(100)), GraphGeometry.minScale);
    });

    test('leaves headroom above the peak', () {
      final s = flat(0)..[30] = 4 * 1024 * 1024;
      expect(GraphGeometry.scaleFor(s), 4 * 1024 * 1024 * 1.25);
    });
  });

  group('points', () {
    test('an idle graph is a flat line on the floor', () {
      final pts = GraphGeometry.points(samples: flat(0), t: 0.5, size: size);
      expect(pts.length, greaterThan(10));
      expect(pts.every((p) => p.dy == size.height), isTrue);
    });

    test('a steady speed is a flat line above the floor', () {
      final pts = GraphGeometry.points(
        samples: flat(1024 * 1024),
        t: 0.3,
        size: size,
      );
      final ys = pts.map((p) => p.dy).toSet();
      expect(ys, hasLength(1));
      expect(ys.single, lessThan(size.height));
      expect(ys.single, greaterThan(0));
    });

    test('everything is inside the box', () {
      final s = [for (var i = 0; i < throughputSamples; i++) i * 90000.0];
      for (final t in [0.0, 0.25, 0.5, 0.99]) {
        for (final p in GraphGeometry.points(samples: s, t: t, size: size)) {
          expect(p.dx, inInclusiveRange(0, size.width), reason: 't=$t');
          expect(p.dy, inInclusiveRange(0, size.height), reason: 't=$t');
        }
      }
    });

    test('points run left to right, and fill the width', () {
      final pts = GraphGeometry.points(samples: flat(5), t: 0.4, size: size);
      for (var i = 1; i < pts.length; i++) {
        expect(pts[i].dx, greaterThanOrEqualTo(pts[i - 1].dx));
      }
      expect(pts.first.dx, 0);
      expect(pts.last.dx, size.width);
    });

    test('a spike is drawn higher than the quiet around it', () {
      final s = flat(0)..[40] = 2 * 1024 * 1024;
      final pts = GraphGeometry.points(samples: s, t: 0.5, size: size);
      final top = pts.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      // The peak uses 80 percent of the scale (1 / 1.25) and the line is drawn
      // within 92 percent of the height, so it sits about a quarter down.
      expect(top, closeTo(size.height - 0.8 * 0.92 * size.height, 0.5));
    });

    test('the line scrolls left as the second goes by', () {
      final s = flat(0)..[30] = 1024 * 1024;
      double xOfPeak(double t) {
        final pts = GraphGeometry.points(samples: s, t: t, size: size);
        return pts.reduce((a, b) => a.dy < b.dy ? a : b).dx;
      }

      expect(xOfPeak(0.5), lessThan(xOfPeak(0.0)));
      expect(xOfPeak(1.0), lessThan(xOfPeak(0.5)));
      // One second is one sixtieth of the width.
      expect(xOfPeak(0.0) - xOfPeak(1.0), closeTo(size.width / 60, 0.01));
    });

    test('there is no jump when a new sample arrives', () {
      // Just before a sample: t is almost 1. Just after: the list has shifted
      // by one and t is back at 0. The line must be in the same place.
      final before = [
        for (var i = 0; i < throughputSamples; i++) (i % 7) * 100000.0,
      ];
      final after = [...before.skip(1), 350000.0];
      final a = GraphGeometry.points(
        samples: before,
        t: 0.999,
        size: size,
        scale: 1000000,
      );
      final b = GraphGeometry.points(
        samples: after,
        t: 0.0,
        size: size,
        scale: 1000000,
      );
      // Compare the line at a handful of x positions.
      double yAt(List<Offset> line, double x) {
        for (var i = 1; i < line.length; i++) {
          if (line[i].dx >= x) {
            final p = line[i - 1];
            final q = line[i];
            final f = q.dx == p.dx ? 0.0 : (x - p.dx) / (q.dx - p.dx);
            return p.dy + (q.dy - p.dy) * f;
          }
        }
        return line.last.dy;
      }

      for (final x in [50.0, 150.0, 300.0, 450.0, 590.0]) {
        expect(yAt(a, x), closeTo(yAt(b, x), 1.5), reason: 'x=$x');
      }
    });

    test('too few samples give nothing to draw', () {
      expect(
        GraphGeometry.points(samples: const [], t: 0, size: size),
        isEmpty,
      );
      expect(
        GraphGeometry.points(samples: const [1], t: 0, size: size),
        isEmpty,
      );
    });
  });

  group('shapes', () {
    test('the area closes down to the floor', () {
      final line = GraphGeometry.points(samples: flat(1e6), t: 0, size: size);
      final bounds = GraphGeometry.area(line, size).getBounds();
      expect(bounds.bottom, size.height);
      expect(bounds.left, 0);
      expect(bounds.right, size.width);
    });

    test('empty lines make empty paths', () {
      expect(GraphGeometry.area(const [], size).getBounds(), Rect.zero);
      expect(GraphGeometry.stroke(const []).getBounds(), Rect.zero);
    });
  });
}
