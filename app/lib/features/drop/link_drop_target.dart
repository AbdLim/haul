import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/cubits/shell_cubit.dart';
import '../../app/motion/motion.dart';
import '../../app/theme/haul_theme.dart';
import 'link_extractor.dart';

/// Holds what a drag over the window is doing. The native drop target feeds
/// it, and tests can drive it directly.
class LinkDropController extends ChangeNotifier {
  bool _active = false;

  /// True while something is being dragged over the window.
  bool get active => _active;

  void enter() {
    if (_active) return;
    _active = true;
    notifyListeners();
  }

  void leave() {
    if (!_active) return;
    _active = false;
    notifyListeners();
  }
}

/// Lets a link be dropped anywhere on the window: while one is dragged over,
/// a full-window overlay says to drop it to download it, and dropping opens
/// the Add URL dialog with the link filled in. A drop with no link in it
/// does nothing.
class LinkDropTarget extends StatefulWidget {
  const LinkDropTarget({
    required this.child,
    this.controller,
    this.native = true,
    super.key,
  });

  final Widget child;

  /// Replaceable for tests.
  final LinkDropController? controller;

  /// False in tests, where there is no native window to receive drops.
  final bool native;

  @override
  State<LinkDropTarget> createState() => _LinkDropTargetState();
}

class _LinkDropTargetState extends State<LinkDropTarget> {
  late final LinkDropController _own = LinkDropController();
  LinkDropController get _controller => widget.controller ?? _own;

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  /// Files were dropped. If one holds a link, open the dialog with it.
  Future<void> dropFiles(List<String> paths) async {
    _controller.leave();
    final link = await LinkExtractor.fromFiles(paths);
    if (link != null && mounted) {
      context.read<ShellCubit>().openAddDialog(url: link.toString());
    }
  }

  /// Plain text was dropped.
  void dropText(String text) {
    _controller.leave();
    final link = LinkExtractor.fromText(text);
    if (link != null) {
      context.read<ShellCubit>().openAddDialog(url: link.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned.fill(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _DropOverlay(active: _controller.active),
          ),
        ),
      ],
    );
    if (!widget.native) return body;
    return DropTarget(
      onDragEntered: (_) => _controller.enter(),
      onDragExited: (_) => _controller.leave(),
      onDragDone: (details) =>
          dropFiles([for (final f in details.files) f.path]),
      child: body,
    );
  }
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    return IgnorePointer(
      ignoring: !active,
      child: AnimatedOpacity(
        duration: Motion.of(context, Motion.dialog),
        curve: Motion.easeOutCubic,
        opacity: active ? 1 : 0,
        child: ColoredBox(
          color: theme.scrim,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.bgElevated,
                borderRadius: BorderRadius.circular(HaulRadii.dialog),
                border: Border.all(color: c.accent, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HaulSpace.xl,
                  vertical: HaulSpace.l,
                ),
                child: Text(
                  'Drop the link to download it',
                  style: theme.text.viewTitle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
