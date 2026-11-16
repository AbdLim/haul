import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../app/motion/motion.dart';
import '../../app/theme/haul_theme.dart';
import 'graph_geometry.dart';

/// The 60-second throughput graph behind the speed readout: an accent-coloured
/// area at low opacity that scrolls smoothly between one-second samples. When
/// nothing is downloading it settles into a flat line and stops animating.
class ThroughputGraph extends StatefulWidget {
  const ThroughputGraph({
    required this.samples,
    required this.lastSampleAt,
    this.now,
    super.key,
  });

  /// Bytes per second, oldest first.
  final List<double> samples;
  final DateTime? lastSampleAt;

  /// The clock, replaceable in tests.
  final DateTime Function()? now;

  @override
  State<ThroughputGraph> createState() => _ThroughputGraphState();
}

class _ThroughputGraphState extends State<ThroughputGraph>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => _progress.value = _t());
  final _progress = ValueNotifier<double>(1);

  bool get _flat => widget.samples.every((s) => s == 0);

  double _t() {
    final at = widget.lastSampleAt;
    if (at == null) return 1;
    final now = (widget.now ?? DateTime.now)();
    return (now.difference(at).inMilliseconds / 1000).clamp(0.0, 1.0);
  }

  void _syncTicker() {
    final animate = !_flat && !Motion.reduce(context);
    if (animate && !_ticker.isActive) {
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _ticker.stop();
      _progress.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(ThroughputGraph old) {
    super.didUpdateWidget(old);
    _syncTicker();
    if (!_ticker.isActive) _progress.value = Motion.reduce(context) ? 1 : _t();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = HaulTheme.of(context).colors;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _GraphPainter(
          samples: widget.samples,
          progress: _progress,
          color: c.accent,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.samples,
    required this.progress,
    required this.color,
  }) : super(repaint: progress);

  final List<double> samples;
  final ValueListenable<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = GraphGeometry.points(
      samples: samples,
      t: progress.value,
      size: size,
    );
    if (line.length < 2) return;

    canvas.drawPath(
      GraphGeometry.area(line, size),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withAlpha(0x40), color.withAlpha(0x05)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      GraphGeometry.stroke(line),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = color.withAlpha(0x70),
    );
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.samples != samples || old.color != color;
}
