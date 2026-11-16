import 'dart:async';

import 'package:download_engine/download_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/cubits/downloads_cubit.dart';
import '../../app/cubits/shell_cubit.dart';
import '../../app/error_text.dart';
import '../../app/format.dart';
import '../../app/motion/motion.dart';
import '../../app/theme/haul_theme.dart';
import '../../data/downloads_dao.dart';
import '../downloads/row_action_runner.dart';
import '../downloads/row_actions.dart';
import '../downloads/row_text.dart';
import '../shell/shell_metrics.dart';
import 'segment_map.dart';
import 'segment_map_geometry.dart';

/// Slides the detail panel in from the right when exactly one download is
/// selected, and out again when it is not. The panel is 340 wide and takes
/// 260 ms (ease out cubic), fading as it moves. With Reduce Motion it only
/// fades.
class DetailPanelHost extends StatefulWidget {
  const DetailPanelHost({super.key});

  @override
  State<DetailPanelHost> createState() => _DetailPanelHostState();
}

class _DetailPanelHostState extends State<DetailPanelHost> {
  /// The last download shown, so the panel can slide out still showing it.
  StoredDownload? _last;

  @override
  Widget build(BuildContext context) {
    final detailId = context.select<ShellCubit, String?>(
      (c) => c.state.detailId,
    );
    final downloads = context.watch<DownloadsCubit>().state;
    final current = detailId == null ? null : downloads.byId(detailId);
    if (current != null) {
      _last = current;
    }
    final visible = current != null;
    final reduced = Motion.reduce(context);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: visible ? 1 : 0),
      duration: Motion.of(context, Motion.detailPanel),
      curve: Motion.easeOutCubic,
      builder: (context, t, _) {
        final shown = _last;
        if (shown == null || (t == 0 && !visible)) {
          return const SizedBox.shrink();
        }
        return ClipRect(
          child: SizedBox(
            width: ShellMetrics.detailWidth * t,
            // Fill the height; a row would otherwise centre a short panel.
            height: double.infinity,
            child: OverflowBox(
              alignment: Alignment.centerRight,
              minWidth: ShellMetrics.detailWidth,
              maxWidth: ShellMetrics.detailWidth,
              child: Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(reduced ? 0 : (1 - t) * 32, 0),
                  child: DetailPanel(download: shown),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Everything about one download: where it is up to, the segment map, a live
/// speed for each connection, the link, where it is saved, any error, and
/// buttons for what can be done with it.
class DetailPanel extends StatefulWidget {
  const DetailPanel({required this.download, super.key});

  final StoredDownload download;

  @override
  State<DetailPanel> createState() => _DetailPanelState();
}

class _DetailPanelState extends State<DetailPanel> {
  final _speeds = ConnectionSpeeds();
  ProgressEvent? _lastEvent;
  StreamSubscription<Map<String, ProgressEvent>>? _sub;
  String? _watching;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watch();
  }

  @override
  void didUpdateWidget(DetailPanel old) {
    super.didUpdateWidget(old);
    _watch();
  }

  /// Listens to live progress for the download shown, to work out each
  /// connection's speed. Switching to another download starts afresh.
  void _watch() {
    if (_watching == widget.download.id && _sub != null) return;
    _sub?.cancel();
    _speeds.clear();
    _lastEvent = null;
    _watching = widget.download.id;
    final live = context.read<LiveCubit>();
    final first = live.state[_watching];
    if (first != null) _speeds.update(first.segments, DateTime.now());
    _lastEvent = first;
    _sub = live.stream.listen((all) {
      final e = all[_watching];
      // The cubit speaks for every running download. An event that is not new
      // for this one would be measured over a few microseconds and show an
      // absurd speed, so only this download's own progress counts.
      if (e == null || !mounted || identical(e, _lastEvent)) return;
      _lastEvent = e;
      setState(() => _speeds.update(e.segments, DateTime.now()));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    final d = widget.download;
    final snap = d.snapshot;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            context.read<ShellCubit>().clearSelection(),
      },
      child: Focus(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.bgSurface,
            border: Border(left: BorderSide(color: c.borderSubtle)),
          ),
          child: BlocSelector<LiveCubit, Map<String, ProgressEvent>, ProgressEvent?>(
            selector: (all) => all[d.id],
            builder: (context, live) {
              // While running, the live segments are the freshest; otherwise
              // the stored ones.
              final segments =
                  snap.status == DownloadStatus.downloading &&
                      live != null &&
                      live.segments.isNotEmpty
                  ? live.segments
                  : snap.segments;
              final connections = [
                for (final s in segments)
                  if (!s.isComplete) s,
              ];
              return SingleChildScrollView(
                padding: const EdgeInsets.all(HaulSpace.l - 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(download: d),
                    const SizedBox(height: HaulSpace.half),
                    Text(
                      // A failure's reason is spelled out under "Problem", so
                      // the line here just says it failed.
                      snap.status == DownloadStatus.failed
                          ? 'Failed'
                          : rowSubtitle(snap, live),
                      style: theme.text.numericSecondary,
                    ),
                    const SizedBox(height: HaulSpace.m),
                    _Label('Segments', theme),
                    if (segments.isEmpty)
                      Text('Not started yet', style: theme.text.secondary)
                    else ...[
                      SegmentMap(segments: segments),
                      const SizedBox(height: 6),
                      Text(
                        '${segments.length} ${segments.length == 1 ? 'connection' : 'connections'} · ${segments.where((s) => s.isComplete).length} done',
                        style: theme.text.caption,
                      ),
                    ],
                    if (snap.status == DownloadStatus.downloading &&
                        connections.isNotEmpty) ...[
                      const SizedBox(height: HaulSpace.m),
                      _Label('Connections', theme),
                      for (var i = 0; i < connections.length; i++)
                        _ConnectionRow(
                          number: i + 1,
                          speed: _speeds.speedOf(connections[i].id),
                          segment: connections[i],
                        ),
                    ],
                    const SizedBox(height: HaulSpace.m),
                    _Label('Link', theme),
                    Text(
                      snap.request.url.toString(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.text.body,
                    ),
                    const SizedBox(height: HaulSpace.m),
                    _Label('Save to', theme),
                    Text(
                      snap.finalPath ?? snap.request.saveDir,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.text.body,
                    ),
                    if (snap.error != null) ...[
                      const SizedBox(height: HaulSpace.m),
                      _Label('Problem', theme),
                      Text(
                        plainError(snap.error),
                        style: theme.text.body.copyWith(color: c.danger),
                      ),
                    ],
                    const SizedBox(height: HaulSpace.l),
                    _Actions(download: d),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.download});
  final StoredDownload download;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            rowTitle(download.snapshot),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.text.heading,
          ),
        ),
        const SizedBox(width: HaulSpace.s),
        HaulIconButton(
          icon: HaulIcons.close,
          tooltip: 'Close',
          onPressed: () => context.read<ShellCubit>().clearSelection(),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, this.theme);
  final String text;
  final HaulTheme theme;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: theme.text.caption),
  );
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({
    required this.number,
    required this.speed,
    required this.segment,
  });

  final int number;
  final double speed;
  final Segment segment;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text('Connection $number', style: theme.text.body)),
          Text(formatSpeed(speed), style: theme.text.numericSecondary),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.download});
  final StoredDownload download;

  @override
  Widget build(BuildContext context) {
    final actions = availableActions([download]);
    return Wrap(
      spacing: HaulSpace.s,
      runSpacing: HaulSpace.s,
      children: [
        for (final a in actions)
          HaulButton(
            label: rowActionLabel(a).replaceAll('…', ''),
            icon: rowActionIcon(a),
            onPressed: () => runRowAction(context, a, [download]),
          ),
      ],
    );
  }
}
