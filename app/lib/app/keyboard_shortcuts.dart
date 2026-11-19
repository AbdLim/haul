import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'commands.dart';

/// The menu bar's commands, as keyboard shortcuts, for the platforms that have
/// no menu bar of their own: the same things, under the Control key, where
/// Windows users look for them.
///
/// The bindings sit near the root of the app, so a text field, whose own
/// shortcuts are nearer the focus, still gets Control-C, Control-V and the
/// rest first.
class HaulShortcuts extends StatelessWidget {
  const HaulShortcuts({
    required this.commands,
    required this.child,
    this.onToggleDetail,
    super.key,
  });

  final HaulCommands commands;
  final Widget child;
  final VoidCallback? onToggleDetail;

  /// Separated out so tests can inspect the shortcuts without a window.
  Map<ShortcutActivator, VoidCallback> bindings() => {
    const SingleActivator(LogicalKeyboardKey.comma, control: true):
        commands.openSettings,
    const SingleActivator(LogicalKeyboardKey.keyN, control: true):
        commands.newDownload,
    const SingleActivator(LogicalKeyboardKey.keyP, control: true, shift: true):
        commands.pauseAll,
    const SingleActivator(LogicalKeyboardKey.keyR, control: true, shift: true):
        commands.resumeAll,
    const SingleActivator(LogicalKeyboardKey.keyX, control: true): commands.cut,
    const SingleActivator(LogicalKeyboardKey.keyC, control: true):
        commands.copy,
    const SingleActivator(LogicalKeyboardKey.keyV, control: true):
        commands.paste,
    const SingleActivator(LogicalKeyboardKey.keyA, control: true):
        commands.selectAll,
    const SingleActivator(LogicalKeyboardKey.digit1, control: true):
        commands.showDownloads,
    const SingleActivator(LogicalKeyboardKey.keyI, control: true):
        ?onToggleDetail,
  };

  @override
  Widget build(BuildContext context) =>
      CallbackShortcuts(bindings: bindings(), child: child);
}
