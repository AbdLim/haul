import 'package:download_engine/download_engine.dart';
import 'package:flutter/widgets.dart';

import '../../app/motion/motion.dart';
import '../../app/theme/haul_theme.dart';
import 'segment_map_geometry.dart';

/// The file drawn as a row of blocks, one per connection, each filling as its
/// part arrives. When a segment is split the block divides in two over 250 ms.
class SegmentMap extends StatefulWidget {
  const SegmentMap({required this.segments, this.height = 28, super.key});

  final List<Segment> segments;
  final double height;

  @override
  State<SegmentMap> createState() => _SegmentMapState();
}

class _SegmentMapState extends State<SegmentMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _split = AnimationController(
    vsync: this,
    duration: Motion.segmentSplit,
    value: 1,
  );

  /// What was drawn at the moment the layout last changed, which the split
  /// animation starts from.
  List<BlockRect> _from = const [];
  List<BlockRect> _to = const [];
  double _width = 0;

  @override
  void dispose() {
    _split.dispose();
    super.dispose();
  }

  List<BlockRect> _current() =>
      lerpBlocks(_from, _to, Motion.easeOut.transform(_split.value));

  void _retarget(List<BlockRect> next) {
    final before = _current();
    final split = gainedBlock(_to, next) && _to.isNotEmpty;
    _from = before;
    _to = next;
    if (split && !Motion.reduce(context)) {
      _split.duration = Motion.segmentSplit;
      _split.forward(from: 0);
    } else {
      // Everything else is just progress, drawn straight away.
      _from = next;
      _split.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HaulTheme.of(context).colors;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final next = layoutBlocks(widget.segments, width);
        if (width != _width || _to.isEmpty || !_sameShape(next, _to)) {
          // Changing the layout while building is fine here: it only picks
          // what the animation will draw; the controller starts after.
          final widthChanged = width != _width;
          _width = width;
          if (widthChanged) {
            _from = next;
            _to = next;
            _split.value = 1;
          } else {
            _retarget(next);
          }
        } else {
          // Same blocks, new fill: no animation, just the new numbers.
          _to = next;
          if (_split.value == 1) _from = next;
        }
        return Semantics(
          label:
              '${widget.segments.length} connections, ${widget.segments.where((s) => s.isComplete).length} done',
          child: SizedBox(
            height: widget.height,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _split,
                builder: (context, _) => CustomPaint(
                  size: Size(width, widget.height),
                  painter: _MapPainter(
                    blocks: _current(),
                    track: c.progressTrack,
                    fill: c.accent,
                    done: c.success,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Whether two layouts have the same blocks in the same places, so only the
  /// fill differs.
  static bool _sameShape(List<BlockRect> a, List<BlockRect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          (a[i].left - b[i].left).abs() > 0.01 ||
          (a[i].right - b[i].right).abs() > 0.01) {
        return false;
      }
    }
    return true;
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.blocks,
    required this.track,
    required this.fill,
    required this.done,
  });

  final List<BlockRect> blocks;
  final Color track;
  final Color fill;
  final Color done;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 1.5;
    for (final b in blocks) {
      final rect = Rect.fromLTRB(
        b.left + gap / 2,
        0,
        (b.right - gap / 2).clamp(b.left + gap / 2, size.width),
        size.height,
      );
      if (rect.width <= 0) continue;
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(rrect, Paint()..color = track);
      if (b.fill > 0) {
        canvas.save();
        canvas.clipRRect(rrect);
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, rect.width * b.fill, rect.height),
          Paint()..color = b.done ? done : fill,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => true;
}
