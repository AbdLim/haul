import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/haul_theme.dart';

class _StepIntent extends Intent {
  const _StepIntent(this.direction);
  final int direction;
}

/// A horizontal slider. Drag it, click the track, or use the arrow keys
/// (Home and End jump to the ends). With [divisions] it snaps to steps.
class HaulSlider extends StatefulWidget {
  const HaulSlider({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeEnd,
    this.semanticLabel,
    super.key,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;

  /// Null disables the slider.
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String? semanticLabel;

  @override
  State<HaulSlider> createState() => _HaulSliderState();
}

class _HaulSliderState extends State<HaulSlider> {
  static const _thumb = 16.0;
  bool _hovered = false;
  bool _dragging = false;
  bool _focused = false;

  bool get _enabled => widget.onChanged != null;
  double get _fraction =>
      ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);

  double _snap(double fraction) {
    var f = fraction.clamp(0.0, 1.0);
    final d = widget.divisions;
    if (d != null && d > 0) f = (f * d).round() / d;
    return widget.min + f * (widget.max - widget.min);
  }

  void _setFromX(double x, double width) {
    final usable = width - _thumb;
    final f = usable <= 0 ? 0.0 : (x - _thumb / 2) / usable;
    widget.onChanged?.call(_snap(f));
  }

  void _step(int direction) {
    final d = widget.divisions;
    final step = d != null && d > 0 ? 1 / d : 0.05;
    widget.onChanged?.call(_snap(_fraction + direction * step));
    widget.onChangeEnd?.call(_snap(_fraction + direction * step));
  }

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;

    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: widget.value.toStringAsFixed(2),
      enabled: _enabled,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowDown): _StepIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowUp): _StepIntent(1),
        },
        actions: {
          _StepIntent: CallbackAction<_StepIntent>(
            onInvoke: (i) {
              _step(i.direction);
              return null;
            },
          ),
        },
        child: Opacity(
          opacity: _enabled ? 1 : 0.4,
          child: LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth;
              final left = _fraction * (width - _thumb);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _enabled
                    ? (d) {
                        _setFromX(d.localPosition.dx, width);
                        widget.onChangeEnd?.call(widget.value);
                      }
                    : null,
                onHorizontalDragStart: _enabled
                    ? (d) {
                        setState(() => _dragging = true);
                        _setFromX(d.localPosition.dx, width);
                      }
                    : null,
                onHorizontalDragUpdate: _enabled
                    ? (d) => _setFromX(d.localPosition.dx, width)
                    : null,
                onHorizontalDragEnd: _enabled
                    ? (_) {
                        setState(() => _dragging = false);
                        widget.onChangeEnd?.call(widget.value);
                      }
                    : null,
                child: SizedBox(
                  height: 24,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Positioned(
                        left: _thumb / 2,
                        right: _thumb / 2,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: c.progressTrack,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Positioned(
                        left: _thumb / 2,
                        child: Container(
                          height: 4,
                          width: _fraction * (width - _thumb),
                          decoration: BoxDecoration(
                            color: c.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Positioned(
                        left: left,
                        child: AnimatedContainer(
                          duration: Motion.of(context, Motion.hover),
                          width: _thumb,
                          height: _thumb,
                          decoration: BoxDecoration(
                            color: _dragging || _hovered
                                ? c.accentText
                                : c.accent,
                            shape: BoxShape.circle,
                            border: _focused
                                ? Border.all(color: c.textPrimary, width: 2)
                                : null,
                            boxShadow: [
                              BoxShadow(color: theme.shadow, blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
