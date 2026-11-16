import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/haul_theme.dart';

class _Dismiss extends Intent {
  const _Dismiss();
}

/// Shows [builder]'s content in a modal route: the backdrop dims, the panel
/// scales from 0.96 to 1 while it fades in (200 ms), and Escape or a click
/// outside closes it unless [barrierDismissible] is off.
Future<T?> showHaulDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final theme = HaulTheme.of(context);
  return Navigator.of(context, rootNavigator: true).push<T>(
    _DialogRoute<T>(
      builder: builder,
      scrim: theme.scrim,
      dismissible: barrierDismissible,
      duration: Motion.of(context, Motion.dialog),
    ),
  );
}

class _DialogRoute<T> extends PopupRoute<T> {
  _DialogRoute({
    required this.builder,
    required this.scrim,
    required this.dismissible,
    required this.duration,
  });

  final WidgetBuilder builder;
  final Color scrim;
  final bool dismissible;
  final Duration duration;

  @override
  Color? get barrierColor => scrim;
  @override
  bool get barrierDismissible => dismissible;
  @override
  String? get barrierLabel => 'Close dialog';
  @override
  Duration get transitionDuration => duration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return FocusScope(
      autofocus: true,
      child: Shortcuts(
        shortcuts: {
          if (dismissible)
            const SingleActivator(LogicalKeyboardKey.escape): const _Dismiss(),
        },
        child: Actions(
          actions: {
            _Dismiss: CallbackAction<_Dismiss>(
              onInvoke: (_) {
                Navigator.of(context).maybePop();
                return null;
              },
            ),
          },
          child: Center(child: builder(context)),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Motion.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween(begin: 0.96, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }
}

/// The frame of a dialog: a title, the content, and a row of buttons.
class HaulDialog extends StatelessWidget {
  const HaulDialog({
    required this.title,
    required this.child,
    this.actions = const [],
    this.width = 440,
    super.key,
  });

  final String title;
  final Widget child;

  /// Buttons, right-aligned. The primary one goes last.
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: title,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: BorderRadius.circular(HaulRadii.dialog),
          border: Border.all(color: c.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: theme.shadow,
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.all(HaulSpace.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: theme.text.heading),
                const SizedBox(height: HaulSpace.m),
                child,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: HaulSpace.l),
                  // Wraps rather than overflows if the buttons do not fit on one
                  // line, for instance with a larger system font.
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: HaulSpace.s,
                      runSpacing: HaulSpace.s,
                      children: actions,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
