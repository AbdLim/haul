import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/haul_theme.dart';

enum HaulProgressTone { accent, success, danger, neutral }

/// A slim progress bar. It eases to each new value over 250 ms, and while
/// [active] a slow sheen travels along the fill. With a null [value] it shows
/// an indeterminate sweep instead.
class HaulProgressBar extends StatefulWidget {
  const HaulProgressBar({
    required this.value,
    this.tone = HaulProgressTone.accent,
    this.active = false,
    this.height = 3,
    super.key,
  });

  /// 0 to 1, or null when the total is unknown.
  final double? value;
  final HaulProgressTone tone;

  /// Whether the transfer is running: turns the sheen on.
  final bool active;
  final double height;

  @override
  State<HaulProgressBar> createState() => _HaulProgressBarState();
}

class _HaulProgressBarState extends State<HaulProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  bool get _animating => widget.active || widget.value == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSheen();
  }

  @override
  void didUpdateWidget(HaulProgressBar old) {
    super.didUpdateWidget(old);
    _syncSheen();
  }

  void _syncSheen() {
    final run = _animating && !Motion.reduce(context);
    if (run && !_sheen.isAnimating) {
      _sheen.repeat();
    } else if (!run && _sheen.isAnimating) {
      _sheen.stop();
    }
  }

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    final fill = switch (widget.tone) {
      HaulProgressTone.accent => c.accent,
      HaulProgressTone.success => c.success,
      HaulProgressTone.danger => c.danger,
      HaulProgressTone.neutral => c.textSecondary,
    };
    final value = widget.value;

    // Its own layer: the sheen repaints every frame, and must not drag the
    // row or the list with it.
    return Semantics(
      value: value == null ? null : '${(value * 100).round()} percent',
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.height),
          child: SizedBox(
            height: widget.height,
            child: LayoutBuilder(
              builder: (context, box) {
                final width = box.maxWidth;
                return Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: c.progressTrack)),
                    if (value == null)
                      _Sweep(controller: _sheen, color: fill, width: width)
                    else
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: value.clamp(0.0, 1.0)),
                        duration: Motion.of(context, Motion.progress),
                        curve: Curves.linear,
                        builder: (context, v, _) => SizedBox(
                          width: width * v,
                          // The fill must have the bar's height itself: with the
                          // sheen as its child it would otherwise shrink to
                          // nothing.
                          height: widget.height,
                          child: AnimatedContainer(
                            duration: Motion.of(context, Motion.complete),
                            curve: Motion.easeOut,
                            color: fill,
                            child: widget.active && v > 0
                                ? _Sheen(controller: _sheen)
                                : null,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A soft band that slides across the filled part.
class _Sheen extends StatelessWidget {
  const _Sheen({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-2 + controller.value * 4, 0),
            end: Alignment(-1 + controller.value * 4, 0),
            colors: const [
              Color(0x00FFFFFF),
              Color(0x38FFFFFF),
              Color(0x00FFFFFF),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sweep extends StatelessWidget {
  const _Sweep({
    required this.controller,
    required this.color,
    required this.width,
  });
  final AnimationController controller;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final band = width * 0.3;
        final x = -band + (width + band) * controller.value;
        return Stack(
          children: [
            Positioned(
              left: x,
              width: band,
              top: 0,
              bottom: 0,
              child: ColoredBox(color: color),
            ),
          ],
        );
      },
    );
  }
}
