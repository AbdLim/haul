import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/cubits/browser_status_cubit.dart';
import '../../app/cubits/downloads_cubit.dart';
import '../../app/cubits/shell_cubit.dart';
import '../../app/motion/motion.dart';
import '../../app/theme/haul_theme.dart';
import '../shell/sidebar_frame.dart';
import 'sidebar_counts.dart';
import 'sidebar_item.dart';

/// The left column: the brand, status filters, category filters, the browser
/// connection indicator and the Settings button.
class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  static const _statusFilters = [
    (StatusFilter.all, HaulIcons.listAll, 'All'),
    (StatusFilter.active, HaulIcons.download, 'Active'),
    (StatusFilter.paused, HaulIcons.pauseCircle, 'Paused'),
    (StatusFilter.completed, HaulIcons.checkCircle, 'Completed'),
    (StatusFilter.failed, HaulIcons.warningCircle, 'Failed'),
  ];

  /// Height of the gap and the "Categories" label between the two groups.
  static const sectionHeader = 36.0;

  static IconData iconForCategory(String name) => switch (name) {
    'Compressed' => HaulIcons.fileZip,
    'Documents' => HaulIcons.fileText,
    'Music' => HaulIcons.music,
    'Video' => HaulIcons.video,
    'Programs' => HaulIcons.program,
    _ => HaulIcons.file,
  };

  /// Where the highlight sits: down from the top of the filter list.
  static double highlightTop({
    required StatusFilter status,
    required int? categoryIndex,
  }) {
    if (categoryIndex != null) {
      return _statusFilters.length * SidebarItem.height +
          sectionHeader +
          categoryIndex * SidebarItem.height;
    }
    final i = _statusFilters.indexWhere((f) => f.$1 == status);
    return i * SidebarItem.height;
  }

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    final shell = context.watch<ShellCubit>();
    final downloads = context.watch<DownloadsCubit>().state;
    final browser = context.watch<BrowserStatusCubit>().state;

    final counts = SidebarCounts.from(downloads.downloads);
    final inSettings = shell.state.section == MainSection.settings;
    final categories = downloads.categories;
    final categoryIndex = shell.state.categoryId == null
        ? null
        : categories.indexWhere((x) => x.id == shell.state.categoryId);

    final top = highlightTop(
      status: shell.state.status,
      categoryIndex: (categoryIndex ?? -1) < 0 ? null : categoryIndex,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SidebarBrand(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: HaulSpace.s),
            child: Stack(
              children: [
                AnimatedPositioned(
                  key: const ValueKey('sidebar-highlight'),
                  duration: Motion.of(context, Motion.sidebarSelection),
                  curve: Motion.easeOutCubic,
                  left: 0,
                  right: 0,
                  top: top,
                  height: SidebarItem.height,
                  child: AnimatedOpacity(
                    duration: Motion.of(context, Motion.hover),
                    opacity: inSettings ? 0 : 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.accent.withAlpha(0x26),
                        borderRadius: BorderRadius.circular(HaulRadii.control),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (filter, icon, label) in _statusFilters)
                      SidebarItem(
                        icon: icon,
                        label: label,
                        count: counts.ofStatus(filter),
                        selected:
                            !inSettings &&
                            shell.state.categoryId == null &&
                            shell.state.status == filter,
                        onPressed: () =>
                            context.read<ShellCubit>().filterByStatus(filter),
                      ),
                    SizedBox(
                      height: sectionHeader,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 0, 6),
                          child: Text(
                            'CATEGORIES',
                            style: theme.text.caption.copyWith(
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (final category in categories)
                      SidebarItem(
                        icon: iconForCategory(category.name),
                        label: category.name,
                        count: counts.ofCategory(category.id),
                        selected:
                            !inSettings &&
                            shell.state.categoryId == category.id,
                        onPressed: () => context
                            .read<ShellCubit>()
                            .filterByCategory(category.id),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(HaulSpace.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BrowserIndicator(status: browser),
              const SizedBox(height: HaulSpace.s),
              _SettingsButton(
                selected: inSettings,
                onPressed: () => context.read<ShellCubit>().toggleSettings(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrowserIndicator extends StatelessWidget {
  const _BrowserIndicator({required this.status});
  final BrowserStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final connected = status == BrowserStatus.connected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Semantics(
        label: connected ? 'Browser connected' : 'Browser not paired',
        child: Row(
          children: [
            AnimatedContainer(
              duration: Motion.of(context, Motion.hover),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected
                    ? theme.colors.success
                    : theme.colors.textSecondary.withAlpha(0x80),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                connected ? 'Browser connected' : 'Browser not paired',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.text.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.selected, required this.onPressed});
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final c = theme.colors;
    return HaulPressable(
      onPressed: onPressed,
      semanticLabel: 'Settings',
      scale: false,
      builder: (context, s) {
        final fg = selected
            ? c.accentText
            : (s.hovered ? c.textPrimary : c.textSecondary);
        return FadeBox(
          color: selected
              ? c.accent.withAlpha(0x26)
              : (s.hovered ? theme.hoverFill : const Color(0x00000000)),
          radius: HaulRadii.control,
          height: SidebarItem.height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              HaulIcon(HaulIcons.gear, size: 16, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Settings',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.text.body.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              Text('⌘,', style: theme.text.caption),
            ],
          ),
        );
      },
    );
  }
}
