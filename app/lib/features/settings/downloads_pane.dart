import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/dependencies.dart';
import '../../app/theme/haul_theme.dart';
import '../../data/setting_keys.dart';
import 'general_pane.dart';
import 'setting_builder.dart';
import 'settings_widgets.dart';
import 'synced_text_field.dart';

class DownloadsPane extends StatelessWidget {
  const DownloadsPane({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final settings = context.read<AppDependencies>().settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: 'Starting downloads',
          children: [
            SettingsRow(
              label: 'Start browser downloads at once',
              help: 'Off shows the New download dialog first.',
              control: SettingToggle(
                settingKey: Keys.autoStartBrowserDownloads,
                label: 'Start browser downloads at once',
              ),
            ),
            SettingsRow(
              label: 'Downloads at the same time',
              help: 'The rest wait in the queue.',
              control: SettingBuilder<int>(
                settingKey: Keys.maxConcurrentDownloads,
                builder: (context, n) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 160,
                      child: HaulSlider(
                        value: n.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        semanticLabel: 'Downloads at the same time',
                        onChanged: (v) => settings.set(
                          Keys.maxConcurrentDownloads,
                          v.round(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$n',
                        textAlign: TextAlign.end,
                        style: theme.text.numeric,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SettingsRow(
              label: 'When the link is already in the list',
              control: SettingBuilder<DuplicateAction>(
                settingKey: Keys.duplicateAction,
                builder: (context, v) => HaulDropdown<DuplicateAction>(
                  width: 220,
                  value: v,
                  items: const [
                    HaulDropdownItem(DuplicateAction.ask, 'Ask me'),
                    HaulDropdownItem(
                      DuplicateAction.numberedCopy,
                      'Add a numbered copy',
                    ),
                    HaulDropdownItem(
                      DuplicateAction.resumeExisting,
                      'Resume the existing one',
                    ),
                  ],
                  onChanged: (a) => settings.set(Keys.duplicateAction, a),
                ),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'Tidying up',
          children: [
            SettingsRow(
              label: 'Remove finished downloads from the list',
              help: 'The files stay where they are saved.',
              control: SettingBuilder<AutoRemove>(
                settingKey: Keys.autoRemoveCompleted,
                builder: (context, v) => HaulDropdown<AutoRemove>(
                  width: 180,
                  value: v,
                  items: const [
                    HaulDropdownItem(AutoRemove.never, 'Never'),
                    HaulDropdownItem(AutoRemove.onQuit, 'When Haul quits'),
                    HaulDropdownItem(AutoRemove.afterSevenDays, 'After 7 days'),
                  ],
                  onChanged: (a) => settings.set(Keys.autoRemoveCompleted, a),
                ),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'Identity',
          children: [
            SettingBuilder<String?>(
              settingKey: Keys.defaultUserAgent,
              builder: (context, ua) => SettingsRow(
                label: 'Default user agent',
                help: 'Sent with every request. Empty uses Haul\'s own.',
                control: SizedBox(
                  width: 260,
                  child: SyncedTextField(
                    label: 'Default user agent',
                    hint: 'Haul\'s own',
                    value: ua ?? '',
                    onChanged: (v) => settings.set(
                      Keys.defaultUserAgent,
                      v.trim().isEmpty ? null : v.trim(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
