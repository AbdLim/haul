import 'dart:math';
import 'dart:ui';

/// Where the throughput line goes. Kept free of widgets so it can be tested
/// exactly.
///
/// The graph shows [windowSeconds] seconds and scrolls continuously. The
/// newest sample is held back one second and slides in from the right edge,
/// so between two samples the line glides instead of stepping; the cost is
/// that the right edge lags the real speed by up to a second.
abstract final class GraphGeometry {
  static const windowSeconds = 60;

  /// The vertical scale never drops below this, so a trickle does not fill
  /// the whole graph and an idle line sits flat on the floor.
  static const minScale = 64 * 1024.0;

  /// The top of the scale for [samples], with headroom above the peak.
  static double scaleFor(List<double> samples) {
    var peak = 0.0;
    for (final s in samples) {
      peak = max(peak, s);
    }
    return max(minScale, peak * 1.25);
  }

  /// The points of the line, left to right, clipped to [size].
  ///
  /// [t] is how far through the current second we are, from 0 to 1.
  static List<Offset> points({
    required List<double> samples,
    required double t,
    required Size size,
    double? scale,
  }) {
    if (samples.length < 2) return const [];
    final top = scale ?? scaleFor(samples);
    final dx = size.width / windowSeconds;
    final n = samples.length;

    double xOf(int i) => size.width - ((n - 1 - i) + t - 1) * dx;
    double yOf(double v) =>
        size.height - (v / top).clamp(0.0, 1.0) * size.height * 0.92;

    final raw = [for (var i = 0; i < n; i++) (x: xOf(i), v: samples[i])];

    final out = <Offset>[];
    for (var i = 0; i < raw.length; i++) {
      final p = raw[i];
      if (p.x < 0) {
        // Keep the crossing point on the left edge.
        if (i + 1 < raw.length && raw[i + 1].x >= 0) {
          out.add(Offset(0, yOf(_lerpAt(p, raw[i + 1], 0))));
        }
        continue;
      }
      if (p.x > size.width) {
        // Keep the crossing point on the right edge, then stop.
        if (i > 0 && raw[i - 1].x <= size.width) {
          out.add(Offset(size.width, yOf(_lerpAt(raw[i - 1], p, size.width))));
        }
        break;
      }
      out.add(Offset(p.x, yOf(p.v)));
    }
    return out;
  }

  /// The value at [x] on the straight line between [a] and [b].
  static double _lerpAt(
    ({double x, double v}) a,
    ({double x, double v}) b,
    double x,
  ) {
    if (b.x == a.x) return b.v;
    final f = (x - a.x) / (b.x - a.x);
    return a.v + (b.v - a.v) * f;
  }

  /// The closed shape to fill under [line], down to the floor.
  static Path area(List<Offset> line, Size size) {
    final path = Path();
    if (line.isEmpty) return path;
    path.moveTo(line.first.dx, size.height);
    for (final p in line) {
      path.lineTo(p.dx, p.dy);
    }
    path.lineTo(line.last.dx, size.height);
    path.close();
    return path;
  }

  static Path stroke(List<Offset> line) {
    final path = Path();
    if (line.isEmpty) return path;
    path.moveTo(line.first.dx, line.first.dy);
    for (final p in line.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }
}
