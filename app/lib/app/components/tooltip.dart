import 'dart:async';

import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/haul_theme.dart';

/// A small label that appears under a control after the pointer has rested on
/// it for half a second. Replaces the stock tooltip.
class HaulTooltip extends StatefulWidget {
  const HaulTooltip({
    required this.message,
    required this.child,
    this.delay = const Duration(milliseconds: 500),
    super.key,
  });

  final String message;
  final Widget child;
  final Duration delay;

  @override
  State<HaulTooltip> createState() => _HaulTooltipState();
}

class _HaulTooltipState extends State<HaulTooltip> {
  final _link = LayerLink();
  OverlayEntry? _entry;
  Timer? _timer;

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(widget.delay, _show);
  }

  void _show() {
    if (_entry != null || !mounted) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomCenter,
          followerAnchor: Alignment.topCenter,
          offset: const Offset(0, 6),
          child: IgnorePointer(child: _Bubble(message: widget.message)),
        ),
      ),
    );
    overlay.insert(_entry!);
  }

  void _hide() {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) => _schedule(),
        onExit: (_) => _hide(),
        child: Listener(onPointerDown: (_) => _hide(), child: widget.child),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, Motion.hover),
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgElevated,
          borderRadius: BorderRadius.circular(HaulRadii.control),
          border: Border.all(color: theme.colors.borderSubtle),
          boxShadow: [BoxShadow(color: theme.shadow, blurRadius: 8)],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            message,
            style: theme.text.caption.copyWith(color: theme.colors.textPrimary),
          ),
        ),
      ),
    );
  }
}
