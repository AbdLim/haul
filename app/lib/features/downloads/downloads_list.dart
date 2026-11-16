import 'package:download_engine/download_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/cubits/downloads_cubit.dart';
import '../../app/cubits/shell_cubit.dart';
import '../../app/motion/animated_list_item.dart';
import '../../app/theme/haul_theme.dart';
import '../../data/downloads_dao.dart';
import '../sidebar/sidebar.dart';
import 'download_row.dart';
import 'empty_state.dart';
import '../updates/update_banner.dart';
import 'first_run_card.dart';
import 'list_logic.dart';
import 'row_action_runner.dart';
import 'row_actions.dart';

/// The list of downloads, newest first, narrowed by the sidebar filter and
/// the search box. Rows slide in and out as downloads come and go, and only
/// the rows on screen are built, so a long list stays light.
class DownloadsList extends StatefulWidget {
  const DownloadsList({super.key});

  @override
  State<DownloadsList> createState() => _DownloadsListState();
}

class _DownloadsListState extends State<DownloadsList> {
  /// The row a Shift-click extends from.
  String? _anchor;
  final _focus = FocusNode(debugLabel: 'downloads list');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// The downloads currently selected, as stored.
  List<StoredDownload> _selected() {
    final ids = context.read<ShellCubit>().state.selection;
    return [
      for (final d in context.read<DownloadsCubit>().state.downloads)
        if (ids.contains(d.id)) d,
    ];
  }

  void _click(List<StoredDownload> visible, String id) {
    final shell = context.read<ShellCubit>();
    final result = clickRow(
      order: [for (final d in visible) d.id],
      current: shell.state.selection,
      anchor: _anchor,
      clicked: id,
      command: HardwareKeyboard.instance.isMetaPressed,
      shift: HardwareKeyboard.instance.isShiftPressed,
    );
    _anchor = result.anchor;
    shell.select(result.selection);
    // Keys such as Space and Delete go to the list once a row is clicked.
    _focus.requestFocus();
  }

  /// The hover button: pause what is running or waiting, resume the rest.
  void _toggle(StoredDownload d) {
    final s = d.snapshot.status;
    final running = s.isActive || s == DownloadStatus.queued;
    runRowAction(context, running ? RowAction.pause : RowAction.resume, [d]);
  }

  /// Space: pause what runs, or resume what is paused.
  void _space() {
    final selected = _selected();
    if (selected.isEmpty) return;
    final action = availableActions(selected).contains(RowAction.pause)
        ? RowAction.pause
        : RowAction.resume;
    runRowAction(context, action, selected);
  }

  /// Right-clicking a row outside the selection selects just that row.
  void _selectForMenu(String id) {
    final shell = context.read<ShellCubit>();
    if (!shell.state.selection.contains(id)) {
      shell.select({id});
      _anchor = id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final downloads = context.watch<DownloadsCubit>().state;
    final shell = context.watch<ShellCubit>().state;
    final visible = visibleDownloads(downloads.downloads, shell);
    final iconById = {
      for (final c in downloads.categories)
        c.id: Sidebar.iconForCategory(c.name),
    };

    final list = ColoredBox(
      color: theme.colors.bgWindow,
      child: HaulAnimatedList<StoredDownload>(
        items: visible,
        idOf: (d) => d.id,
        padding: const EdgeInsets.only(top: HaulSpace.s, bottom: HaulSpace.l),
        itemBuilder: (context, d, index) => DownloadRow(
          download: d,
          icon: iconById[d.categoryId] ?? Sidebar.iconForCategory(''),
          selected: shell.selection.contains(d.id),
          onPressed: () => _click(visible, d.id),
          onTogglePause: () => _toggle(d),
          onMenuOpen: () => _selectForMenu(d.id),
          menuBuilder: (_) => buildRowMenu(
            _selected(),
            (action) => runRowAction(context, action, _selected()),
          ),
        ),
      ),
    );

    // Nothing to show: say why, once the first load is in. The list stays
    // mounted underneath so the last row can still slide out.
    final showEmpty = downloads.loaded && visible.isEmpty;
    final body = Stack(
      children: [
        Positioned.fill(child: list),
        if (showEmpty) const Positioned.fill(child: DownloadsEmptyState()),
      ],
    );

    return BlocListener<DownloadsCubit, DownloadsState>(
      // Rows that disappear must not stay selected.
      listenWhen: (a, b) => a.downloads.length != b.downloads.length,
      listener: (context, state) => context.read<ShellCubit>().forget({
        for (final d in state.downloads) d.id,
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => context.read<ShellCubit>().clearSelection(),
        child: _ListKeys(
          focusNode: _focus,
          onSpace: _space,
          onRemove: () => runRowAction(context, RowAction.remove, _selected()),
          onClear: () => context.read<ShellCubit>().clearSelection(),
          child: Column(
            children: [
              const UpdateBanner(),
              const FirstRunCard(),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpaceIntent extends Intent {
  const _SpaceIntent();
}

class _RemoveIntent extends Intent {
  const _RemoveIntent();
}

class _ClearIntent extends Intent {
  const _ClearIntent();
}

/// The list's keyboard shortcuts: Space pauses or resumes the selection,
/// Delete removes it from the list, Escape clears the selection.
class _ListKeys extends StatelessWidget {
  const _ListKeys({
    required this.focusNode,
    required this.onSpace,
    required this.onRemove,
    required this.onClear,
    required this.child,
  });

  final FocusNode focusNode;
  final VoidCallback onSpace;
  final VoidCallback onRemove;
  final VoidCallback onClear;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Key events travel up from the focused widget, so the shortcuts have to
    // sit above the focus node, not below it.
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.space): _SpaceIntent(),
        SingleActivator(LogicalKeyboardKey.delete): _RemoveIntent(),
        SingleActivator(LogicalKeyboardKey.backspace): _RemoveIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _ClearIntent(),
      },
      child: Actions(
        actions: {
          _SpaceIntent: CallbackAction<_SpaceIntent>(
            onInvoke: (_) => onSpace(),
          ),
          _RemoveIntent: CallbackAction<_RemoveIntent>(
            onInvoke: (_) => onRemove(),
          ),
          _ClearIntent: CallbackAction<_ClearIntent>(
            onInvoke: (_) => onClear(),
          ),
        },
        child: Focus(focusNode: focusNode, child: child),
      ),
    );
  }
}
