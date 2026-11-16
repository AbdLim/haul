import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/haul_theme.dart';
import 'button.dart';

class HaulSegment<T> {
  const HaulSegment(this.value, this.label);
  final T value;
  final String label;
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.direction);
  final int direction;
}

/// A row of options of which one is chosen, with a highlight that slides to
/// the new choice. Left and right arrows move the choice from the keyboard.
class HaulSegmentedControl<T> extends StatefulWidget {
  const HaulSegmentedControl({
    required this.segments,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<HaulSegment<T>> segments;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  State<HaulSegmentedControl<T>> createState() =>
      _HaulSegmentedControlState<T>();
}

class _HaulSegmentedControlState<T> extends State<HaulSegmentedControl<T>> {
  bool _focused = false;
  int? _hovered;

  int get _index {
    final i = widget.segments.indexWhere((s) => s.value == widget.value);
    return i < 0 ? 0 : i;
  }

  void _move(int direction) {
    final n = widget.segments.length;
    final next = (_index + direction).clamp(0, n - 1);
    if (next != _index) widget.onChanged?.call(widget.segments[next].value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    final n = widget.segments.length;
    final enabled = widget.onChanged != null;
    // Alignment runs from -1 (first) to 1 (last).
    final x = n <= 1 ? -1.0 : -1 + 2 * _index / (n - 1);

    return FocusableActionDetector(
      enabled: enabled,
      mouseCursor: SystemMouseCursors.basic,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowRight): _MoveIntent(1),
      },
      actions: {
        _MoveIntent: CallbackAction<_MoveIntent>(
          onInvoke: (i) {
            _move(i.direction);
            return null;
          },
        ),
      },
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: IntrinsicWidth(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.bgSurface,
              borderRadius: BorderRadius.circular(HaulRadii.control),
              border: Border.all(
                color: _focused ? c.accent : c.borderSubtle,
                width: _focused ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: SizedBox(
                height: haulControlHeight - 6,
                child: Stack(
                  children: [
                    AnimatedAlign(
                      key: const ValueKey('segment-highlight'),
                      duration: Motion.of(context, Motion.sidebarSelection),
                      curve: Motion.easeOutCubic,
                      alignment: Alignment(x, 0),
                      child: FractionallySizedBox(
                        widthFactor: 1 / n,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.bgElevated,
                            borderRadius: BorderRadius.circular(
                              HaulRadii.control - 2,
                            ),
                            border: Border.all(color: c.borderSubtle),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < n; i++)
                          Expanded(
                            child: MouseRegion(
                              onEnter: (_) => setState(() => _hovered = i),
                              onExit: (_) => setState(() => _hovered = null),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: enabled
                                    ? () => widget.onChanged!(
                                        widget.segments[i].value,
                                      )
                                    : null,
                                child: Semantics(
                                  button: true,
                                  selected: i == _index,
                                  label: widget.segments[i].label,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Center(
                                      child: AnimatedDefaultTextStyle(
                                        duration: Motion.of(
                                          context,
                                          Motion.hover,
                                        ),
                                        style: theme.text.body.copyWith(
                                          fontWeight: i == _index
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: i == _index || _hovered == i
                                              ? c.textPrimary
                                              : c.textSecondary,
                                        ),
                                        child: Text(widget.segments[i].label),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
