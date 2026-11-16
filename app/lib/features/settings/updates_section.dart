import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/cubits/update_cubit.dart';
import '../../app/theme/haul_theme.dart';
import '../../data/setting_keys.dart';
import '../updates/update_actions.dart';
import 'general_pane.dart';
import 'settings_widgets.dart';

/// Settings, About: whether to look for updates, and a button to look now.
class UpdatesSection extends StatelessWidget {
  const UpdatesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Updates',
      children: [
        SettingsRow(
          label: 'Check for updates automatically',
          help:
              'Once a day Haul asks GitHub whether a newer version exists. '
              'Nothing else is sent.',
          control: SettingToggle(
            settingKey: Keys.checkForUpdates,
            label: 'Check for updates automatically',
          ),
        ),
        BlocBuilder<UpdateCubit, UpdateState>(
          builder: (context, state) {
            final info = state.info;
            final checking = state.status == UpdateStatus.checking;
            final text = switch (state.status) {
              UpdateStatus.checking => 'Checking…',
              UpdateStatus.upToDate => 'Haul is up to date.',
              UpdateStatus.available => 'Haul ${info?.version} is available.',
              UpdateStatus.failed => state.error ?? "Couldn't check right now.",
              UpdateStatus.idle => null,
            };
            return SettingsRow(
              label: 'Check now',
              help: text,
              control: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.status == UpdateStatus.available &&
                      info != null) ...[
                    HaulButton(
                      label: "What's new",
                      onPressed: () => showWhatsNew(context, info),
                    ),
                    const SizedBox(width: HaulSpace.s),
                  ],
                  HaulButton(
                    label: checking ? 'Checking…' : 'Check now',
                    onPressed: checking
                        ? null
                        : () => context.read<UpdateCubit>().checkNow(),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
