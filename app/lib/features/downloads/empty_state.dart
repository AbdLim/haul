import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/cubits/downloads_cubit.dart';
import '../../app/cubits/shell_cubit.dart';
import '../../app/haul_mark.dart';
import '../../app/motion/motion.dart';
import '../../app/theme/haul_theme.dart';

/// What the list shows when it has nothing to show. With no downloads at all
/// it invites the first one; with a filter or a search that matches nothing
/// it says so and does not push the Add button.
class DownloadsEmptyState extends StatelessWidget {
  const DownloadsEmptyState({super.key});

  static String filteredMessage(ShellState shell, DownloadsState downloads) {
    if (shell.query.trim().isNotEmpty) {
      return 'Nothing matches "${shell.query.trim()}"';
    }
    if (shell.categoryId != null) {
      final name = downloads.categories
          .where((c) => c.id == shell.categoryId)
          .map((c) => c.name)
          .firstOrNull;
      return name == null ? 'Nothing here' : 'No downloads in $name';
    }
    return switch (shell.status) {
      StatusFilter.all => 'Nothing here',
      StatusFilter.active => 'Nothing is downloading',
      StatusFilter.paused => 'Nothing is paused',
      StatusFilter.completed => 'Nothing has finished yet',
      StatusFilter.failed => 'Nothing has failed',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final shell = context.watch<ShellCubit>().state;
    final downloads = context.watch<DownloadsCubit>().state;
    final none = downloads.downloads.isEmpty;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, Motion.viewSwitch),
      curve: Motion.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (none) ...[
              const HaulMark(size: 56),
              const SizedBox(height: HaulSpace.m),
              Text(
                'Paste a link or press ⌘N to add a download',
                style: theme.text.body,
              ),
              const SizedBox(height: HaulSpace.m),
              HaulButton(
                label: 'Add URL',
                icon: HaulIcons.plus,
                kind: HaulButtonKind.primary,
                onPressed: () => context.read<ShellCubit>().openAddDialog(),
              ),
            ] else
              Text(
                filteredMessage(shell, downloads),
                style: theme.text.secondary,
              ),
          ],
        ),
      ),
    );
  }
}
