import 'package:flutter/widgets.dart';

import '../../app/motion/motion.dart';

/// A check mark that draws itself over 500 ms (ease out) when [animate] is
/// set, and simply appears otherwise. With Reduce Motion it fades in over
/// 120 ms instead of being drawn.
class CompletionCheck extends StatefulWidget {
  const CompletionCheck({
    required this.color,
    required this.animate,
    this.size = 18,
    super.key,
  });

  final Color color;
  final bool animate;
  final double size;

  @override
  State<CompletionCheck> createState() => _CompletionCheckState();
}

class _CompletionCheckState extends State<CompletionCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.complete,
    value: widget.animate ? 0 : 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = Motion.of(context, Motion.complete);
    if (widget.animate && _controller.value == 0 && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(CompletionCheck old) {
    super.didUpdateWidget(old);
    if (widget.animate && !old.animate) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduce(context);
    return Semantics(
      label: 'Completed',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Motion.easeOut.transform(_controller.value);
          return Opacity(
            opacity: reduced ? t : 1,
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _CheckPainter(
                color: widget.color,
                progress: reduced ? 1 : t,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.16, size.height * 0.54)
      ..lineTo(size.width * 0.40, size.height * 0.76)
      ..lineTo(size.width * 0.84, size.height * 0.26);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
