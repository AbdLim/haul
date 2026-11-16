import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/haul_theme.dart';

/// What a control looks like right now.
@immutable
class HaulControlState {
  const HaulControlState({
    this.hovered = false,
    this.pressed = false,
    this.focused = false,
    this.enabled = true,
  });

  final bool hovered;
  final bool pressed;

  /// Keyboard focus only. A mouse click does not make a focus ring appear.
  final bool focused;
  final bool enabled;
}

/// The one place that handles hover, press, keyboard focus and disabling, so
/// every component behaves the same: a colour fade on hover, a 0.97 scale on
/// press, a visible focus ring from the keyboard, Space and Enter to
/// activate, and the pointer left as an arrow.
class HaulPressable extends StatefulWidget {
  const HaulPressable({
    required this.builder,
    this.onPressed,
    this.onSecondaryPressed,
    this.focusNode,
    this.autofocus = false,
    this.scale = true,
    this.focusRingRadius = HaulRadii.control,
    this.focusRing = true,
    this.semanticLabel,
    super.key,
  });

  final Widget Function(BuildContext context, HaulControlState state) builder;

  /// Null disables the control.
  final VoidCallback? onPressed;
  final VoidCallback? onSecondaryPressed;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Whether pressing shrinks the control slightly.
  final bool scale;
  final double focusRingRadius;
  final bool focusRing;
  final String? semanticLabel;

  @override
  State<HaulPressable> createState() => _HaulPressableState();
}

class _HaulPressableState extends State<HaulPressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  void _set({bool? hovered, bool? pressed, bool? focused}) {
    final h = hovered ?? _hovered;
    final p = pressed ?? _pressed;
    final f = focused ?? _focused;
    if (h == _hovered && p == _pressed && f == _focused) return;
    setState(() {
      _hovered = h;
      _pressed = p;
      _focused = f;
    });
  }

  @override
  void didUpdateWidget(HaulPressable old) {
    super.didUpdateWidget(old);
    // A control that gets disabled while pressed must let go.
    if (!_enabled && (_pressed || _hovered)) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final state = HaulControlState(
      hovered: _hovered && _enabled,
      pressed: _pressed && _enabled,
      focused: _focused && _enabled,
      enabled: _enabled,
    );

    Widget content = widget.builder(context, state);
    if (widget.scale) {
      content = PressScale(pressed: state.pressed, child: content);
    }
    if (widget.focusRing) {
      content = _FocusRing(
        visible: state.focused,
        radius: widget.focusRingRadius,
        color: theme.colors.accent,
        child: content,
      );
    }

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: _enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => _set(hovered: v),
        onShowFocusHighlight: (v) => _set(focused: v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => _set(pressed: true) : null,
          onTapUp: _enabled ? (_) => _set(pressed: false) : null,
          onTapCancel: _enabled ? () => _set(pressed: false) : null,
          onTap: widget.onPressed,
          onSecondaryTap: widget.onSecondaryPressed,
          child: content,
        ),
      ),
    );
  }
}

/// A 2-point accent ring just outside the control, for keyboard focus.
class _FocusRing extends StatelessWidget {
  const _FocusRing({
    required this.visible,
    required this.radius,
    required this.color,
    required this.child,
  });

  final bool visible;
  final double radius;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: visible ? Border.all(color: color, width: 2) : null,
      ),
      child: child,
    );
  }
}

/// Colour that fades over 120 ms (ease out) to follow a changing state.
class FadeBox extends StatelessWidget {
  const FadeBox({
    required this.color,
    required this.radius,
    this.border,
    this.padding,
    this.child,
    this.height,
    this.width,
    this.alignment,
    super.key,
  });

  final Color color;
  final double radius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final Widget? child;
  final double? height;
  final double? width;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.of(context, Motion.hover),
      curve: Motion.easeOut,
      height: height,
      width: width,
      padding: padding,
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
      child: child,
    );
  }
}
