import 'package:download_engine/download_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/cubits/downloads_cubit.dart';
import '../../app/cubits/shell_cubit.dart';
import '../../app/cubits/throughput_cubit.dart';
import '../../app/format.dart';
import '../../app/motion/animated_number.dart';
import '../../app/theme/haul_theme.dart';
import 'throughput_graph.dart';

/// The band across the top of the list: the total speed as a big number with
/// the active count and time left under it, a 60-second graph behind them,
/// and on the right the Add URL button, Pause all, Resume all and search.
class HeaderBand extends StatelessWidget {
  const HeaderBand({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Nothing here takes clicks, so they fall through to the layer behind
        // the header that drags and zooms the window.
        Positioned.fill(
          child: IgnorePointer(
            child: BlocBuilder<ThroughputCubit, ThroughputState>(
              buildWhen: (a, b) => a.samples != b.samples,
              builder: (context, s) => ThroughputGraph(
                samples: s.samples,
                lastSampleAt: s.lastSampleAt,
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: HaulSpace.l,
            vertical: HaulSpace.m,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: IgnorePointer(child: _SpeedReadout())),
              SizedBox(width: HaulSpace.m),
              _Controls(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpeedReadout extends StatelessWidget {
  const _SpeedReadout();

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    return BlocBuilder<ThroughputCubit, ThroughputState>(
      builder: (context, s) {
        // Idle shows words, never a stale or zero number.
        if (s.idle) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Nothing downloading',
              style: theme.text.viewTitle.copyWith(
                color: theme.colors.textSecondary,
              ),
            ),
          );
        }
        final eta = s.eta;
        final detail = StringBuffer('${s.activeCount} active');
        if (eta != null) detail.write(' · ${formatEta(eta)} left');
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedNumber(
              value: s.speed,
              format: formatSpeed,
              style: theme.text.display,
            ),
            const SizedBox(height: HaulSpace.half),
            Text(detail.toString(), style: theme.text.numericSecondary),
          ],
        );
      },
    );
  }
}

class _Controls extends StatefulWidget {
  const _Controls();

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.read<ShellCubit>();
    final downloads = context.watch<DownloadsCubit>();

    var anyRunning = false;
    var anyResumable = false;
    for (final d in downloads.state.downloads) {
      final st = d.snapshot.status;
      if (st.isActive || st == DownloadStatus.queued) anyRunning = true;
      if (st.canResume && st != DownloadStatus.needsRefresh) {
        anyResumable = true;
      }
    }

    // Keep the box in step if something else clears the search.
    return BlocListener<ShellCubit, ShellState>(
      listenWhen: (a, b) => a.query != b.query && b.query != _search.text,
      listener: (context, state) => _search.text = state.query,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HaulButton(
            label: 'Add URL',
            icon: HaulIcons.plus,
            kind: HaulButtonKind.primary,
            onPressed: shell.openAddDialog,
          ),
          const SizedBox(width: HaulSpace.s),
          HaulIconButton(
            icon: HaulIcons.pause,
            tooltip: 'Pause all',
            onPressed: anyRunning ? downloads.pauseAll : null,
          ),
          HaulIconButton(
            icon: HaulIcons.play,
            tooltip: 'Resume all',
            onPressed: anyResumable ? downloads.resumeAll : null,
          ),
          const SizedBox(width: HaulSpace.s),
          SizedBox(
            width: 200,
            child: HaulTextField(
              controller: _search,
              hint: 'Search',
              semanticLabel: 'Search downloads',
              leading: HaulIcon(
                HaulIcons.search,
                color: HaulTheme.of(context).colors.textSecondary,
              ),
              onChanged: shell.setQuery,
            ),
          ),
        ],
      ),
    );
  }
}
