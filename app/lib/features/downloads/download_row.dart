import 'package:download_engine/download_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/cubits/downloads_cubit.dart';
import '../../app/cubits/setting_cubit.dart';
import '../../app/motion/motion.dart';
import '../../app/theme/haul_theme.dart';
import '../../data/downloads_dao.dart';
import '../../data/setting_keys.dart';
import '../shell/shell_metrics.dart';
import 'completion_check.dart';
import 'row_action_runner.dart';
import 'row_actions.dart';
import 'row_text.dart';

/// One download in the list: a file-type tile, the name, a line of sizes and
/// speed or the state in words, and a slim progress bar along the bottom
/// edge. A pause or resume button appears on hover.
class DownloadRow extends StatefulWidget {
  const DownloadRow({
    required this.download,
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.onTogglePause,
    this.menuBuilder,
    this.onMenuOpen,
    super.key,
  });

  final StoredDownload download;

  /// The tile's icon, from the download's category.
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  /// Pause or resume, whichever fits the state. Null hides the button.
  final VoidCallback? onTogglePause;

  /// Items for the right-click menu. Null means no menu.
  final List<HaulMenuEntry> Function(BuildContext context)? menuBuilder;

  /// Runs just before the menu opens, to select this row.
  final VoidCallback? onMenuOpen;

  @override
  State<DownloadRow> createState() => _DownloadRowState();
}

class _DownloadRowState extends State<DownloadRow> {
  bool _hovered = false;

  /// Set when this row has just turned from running to complete, so the check
  /// mark draws itself. A row that was already complete when it appeared just
  /// shows the tick.
  bool _justCompleted = false;

  @override
  void didUpdateWidget(DownloadRow old) {
    super.didUpdateWidget(old);
    final was = old.download.snapshot.status;
    final now = widget.download.snapshot.status;
    if (was != DownloadStatus.completed && now == DownloadStatus.completed) {
      _justCompleted = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    final snap = widget.download.snapshot;

    Widget row = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Semantics(
          selected: widget.selected,
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.hover),
            curve: Motion.easeOut,
            height:
                context.select<SettingCubit<ListDensity>, ListDensity>(
                      (c) => c.state,
                    ) ==
                    ListDensity.compact
                ? ShellMetrics.compactRowHeight
                : ShellMetrics.rowHeight,
            margin: const EdgeInsets.symmetric(
              horizontal: HaulSpace.m,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: widget.selected
                  ? c.accent.withAlpha(0x22)
                  : (_hovered ? c.bgSurface : c.bgSurface.withAlpha(0)),
              borderRadius: BorderRadius.circular(HaulRadii.row),
              border: Border.all(
                color: widget.selected
                    ? c.accent.withAlpha(0x66)
                    : c.bgSurface.withAlpha(0),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(HaulRadii.row),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _Tile(icon: widget.icon),
                        const SizedBox(width: 12),
                        Expanded(child: _Texts(download: widget.download)),
                        const SizedBox(width: 8),
                        _Trailing(
                          download: widget.download,
                          status: snap.status,
                          hovered: _hovered,
                          justCompleted: _justCompleted,
                          onTogglePause: widget.onTogglePause,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _Bar(download: widget.download),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.menuBuilder != null) {
      row = HaulContextMenuRegion(
        onOpen: widget.onMenuOpen,
        entriesBuilder: widget.menuBuilder!,
        child: row,
      );
    }
    return row;
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = HaulTheme.of(context).colors;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.bgWindow,
        borderRadius: BorderRadius.circular(HaulRadii.control),
        border: Border.all(color: c.borderSubtle),
      ),
      child: HaulIcon(icon, size: 20, color: c.textSecondary),
    );
  }
}

/// The name and the second line. Only this part listens to live progress, so
/// a running download redraws two lines of text and a bar, not the list.
class _Texts extends StatelessWidget {
  const _Texts({required this.download});
  final StoredDownload download;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final snap = download.snapshot;
    return BlocSelector<LiveCubit, Map<String, ProgressEvent>, ProgressEvent?>(
      selector: (live) => live[download.id],
      builder: (context, live) {
        final failed =
            snap.status == DownloadStatus.failed ||
            snap.status == DownloadStatus.needsRefresh;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rowTitle(snap),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.text.bodyStrong,
            ),
            const SizedBox(height: 2),
            Text(
              rowSubtitle(snap, live),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: failed
                  ? theme.text.numericSecondary.copyWith(
                      color: theme.colors.danger,
                    )
                  : theme.text.numericSecondary,
            ),
          ],
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.download});
  final StoredDownload download;

  @override
  Widget build(BuildContext context) {
    final snap = download.snapshot;
    return BlocSelector<LiveCubit, Map<String, ProgressEvent>, ProgressEvent?>(
      selector: (live) => live[download.id],
      builder: (context, live) => HaulProgressBar(
        value: snap.status == DownloadStatus.probing
            ? null
            : rowProgress(snap, live),
        tone: rowTone(snap.status),
        active: snap.status == DownloadStatus.downloading,
        height: 3,
      ),
    );
  }
}

class _Trailing extends StatelessWidget {
  const _Trailing({
    required this.download,
    required this.status,
    required this.hovered,
    required this.justCompleted,
    required this.onTogglePause,
  });

  final StoredDownload download;
  final DownloadStatus status;
  final bool hovered;
  final bool justCompleted;
  final VoidCallback? onTogglePause;

  @override
  Widget build(BuildContext context) {
    final c = HaulTheme.of(context).colors;
    if (status == DownloadStatus.completed) {
      return CompletionCheck(color: c.success, animate: justCompleted);
    }
    // A failed row always has its way out in view, not behind a hover.
    if (status == DownloadStatus.failed) {
      return HaulButton(
        label: 'Retry',
        icon: HaulIcons.retry,
        onPressed: () => runRowAction(context, RowAction.retry, [download]),
      );
    }
    if (status == DownloadStatus.needsRefresh) {
      return HaulButton(
        label: 'New link',
        icon: HaulIcons.link,
        onPressed: () =>
            runRowAction(context, RowAction.refreshLink, [download]),
      );
    }
    final running = status.isActive || status == DownloadStatus.queued;
    final canToggle =
        onTogglePause != null &&
        status != DownloadStatus.needsRefresh &&
        status != DownloadStatus.completed;
    if (!canToggle) return const SizedBox(width: haulControlHeight);
    return AnimatedOpacity(
      duration: Motion.of(context, Motion.hover),
      opacity: hovered ? 1 : 0,
      child: IgnorePointer(
        ignoring: !hovered,
        child: HaulIconButton(
          icon: running ? HaulIcons.pause : HaulIcons.play,
          tooltip: running ? 'Pause' : 'Resume',
          onPressed: onTogglePause,
        ),
      ),
    );
  }
}
