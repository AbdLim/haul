import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/dependencies.dart';
import '../../data/setting_keys.dart';
import 'general_pane.dart';
import 'setting_builder.dart';
import 'settings_widgets.dart';

class AppearancePane extends StatelessWidget {
  const AppearancePane({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.read<AppDependencies>().settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: 'Look',
          children: [
            SettingsRow(
              label: 'Theme',
              help: 'System follows your Mac.',
              control: SettingBuilder<AppThemeMode>(
                settingKey: Keys.themeMode,
                builder: (context, mode) => SizedBox(
                  width: 240,
                  child: HaulSegmentedControl<AppThemeMode>(
                    segments: const [
                      HaulSegment(AppThemeMode.system, 'System'),
                      HaulSegment(AppThemeMode.dark, 'Dark'),
                      HaulSegment(AppThemeMode.light, 'Light'),
                    ],
                    value: mode,
                    onChanged: (v) => settings.set(Keys.themeMode, v),
                  ),
                ),
              ),
            ),
            SettingsRow(
              label: 'List density',
              help: 'Compact fits more downloads on screen.',
              control: SettingBuilder<ListDensity>(
                settingKey: Keys.listDensity,
                builder: (context, d) => SizedBox(
                  width: 240,
                  child: HaulSegmentedControl<ListDensity>(
                    segments: const [
                      HaulSegment(ListDensity.comfortable, 'Comfortable'),
                      HaulSegment(ListDensity.compact, 'Compact'),
                    ],
                    value: d,
                    onChanged: (v) => settings.set(Keys.listDensity, v),
                  ),
                ),
              ),
            ),
            SettingsRow(
              label: 'Show speed in the menu bar',
              help: 'Total download speed next to the Haul icon.',
              control: SettingToggle(
                settingKey: Keys.showSpeedInMenuBar,
                label: 'Show speed in the menu bar',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
