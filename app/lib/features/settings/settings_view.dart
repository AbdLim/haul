import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/cubits/shell_cubit.dart';
import '../../app/dependencies.dart';
import '../../app/motion/motion.dart';
import '../../app/theme/haul_theme.dart';
import '../shell/header_drag_area.dart';
import 'about_pane.dart';
import 'appearance_pane.dart';
import 'connection_pane.dart';
import 'notifications_pane.dart';
import 'proxy_pane.dart';
import 'site_logins_pane.dart';
import 'downloads_pane.dart';
import 'file_types_pane.dart';
import 'save_to_pane.dart';
import 'general_pane.dart';
import 'reset_pane.dart';
import 'settings_pane.dart';

/// The Settings view, which takes the place of the downloads: a list of panes
/// on the left and the chosen pane on the right. Every control saves as it is
/// changed; there is no Save button. Escape goes back to the downloads.
class SettingsView extends StatelessWidget {
  const SettingsView({this.native = true, super.key});

  final bool native;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final pane = context.select<ShellCubit, SettingsPane>(
      (c) => c.state.settingsPane,
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            context.read<ShellCubit>().showDownloads(),
      },
      child: Focus(
        autofocus: true,
        child: ColoredBox(
          color: theme.colors.bgWindow,
          child: Row(
            children: [
              const _PaneList(),
              Container(width: 1, color: theme.colors.borderSubtle),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 72,
                      child: HeaderDragArea(
                        enabled: native,
                        onDoubleTap: context
                            .read<AppDependencies>()
                            .chrome
                            .toggleZoom,
                        child: _PaneHeader(pane: pane),
                      ),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: Motion.of(context, Motion.viewSwitch),
                        child: SingleChildScrollView(
                          key: ValueKey(pane),
                          padding: const EdgeInsets.fromLTRB(
                            HaulSpace.l,
                            HaulSpace.s,
                            HaulSpace.l,
                            HaulSpace.l,
                          ),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: _body(pane),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _body(SettingsPane pane) => switch (pane) {
    SettingsPane.general => const GeneralPane(),
    SettingsPane.fileTypes => const FileTypesPane(),
    SettingsPane.saveTo => const SaveToPane(),
    SettingsPane.downloads => const DownloadsPane(),
    SettingsPane.connection => const ConnectionPane(),
    SettingsPane.proxy => const ProxyPane(),
    SettingsPane.siteLogins => const SiteLoginsPane(),
    SettingsPane.notifications => const NotificationsPane(),
    SettingsPane.appearance => const AppearancePane(),
    SettingsPane.about => const AboutPane(),
  };
}

class _PaneHeader extends StatelessWidget {
  const _PaneHeader({required this.pane});
  final SettingsPane pane;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HaulSpace.l,
        HaulSpace.l,
        HaulSpace.l,
        HaulSpace.s,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              pane.title,
              style: theme.text.heading.copyWith(fontSize: 20),
            ),
          ),
          if (pane.keys.isNotEmpty)
            HaulButton(
              label: 'Reset this pane',
              kind: HaulButtonKind.ghost,
              onPressed: () => resetPane(context.read<AppDependencies>(), pane),
            ),
          const SizedBox(width: HaulSpace.s),
          HaulButton(
            label: 'Done',
            kind: HaulButtonKind.primary,
            onPressed: () => context.read<ShellCubit>().showDownloads(),
          ),
        ],
      ),
    );
  }
}

class _PaneList extends StatelessWidget {
  const _PaneList();

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final selected = context.select<ShellCubit, SettingsPane>(
      (c) => c.state.settingsPane,
    );
    return SizedBox(
      width: 200,
      child: ListView(
        padding: const EdgeInsets.all(HaulSpace.s),
        children: [
          const SizedBox(height: HaulSpace.m),
          for (final p in SettingsPane.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: HaulPressable(
                semanticLabel: p.title,
                onPressed: () => context.read<ShellCubit>().selectPane(p),
                builder: (context, state) => AnimatedContainer(
                  duration: Motion.of(context, Motion.hover),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(HaulRadii.control),
                    color: p == selected
                        ? theme.colors.accent.withAlpha(0x22)
                        : (state.hovered ? theme.hoverFill : null),
                  ),
                  child: Text(
                    p.title,
                    style: p == selected
                        ? theme.text.bodyStrong
                        : theme.text.body,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
