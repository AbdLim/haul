import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/cubits/browser_status_cubit.dart';
import '../../app/dependencies.dart';
import '../../app/theme/haul_theme.dart';
import '../../data/setting_key.dart';
import '../../data/setting_keys.dart';
import '../../services/bridge/bridge_controller.dart';
import 'setting_builder.dart';
import 'synced_text_field.dart';
import 'settings_widgets.dart';

/// A toggle bound to a boolean setting.
class SettingToggle extends StatelessWidget {
  const SettingToggle({
    required this.settingKey,
    required this.label,
    super.key,
  });

  final SettingKey<bool> settingKey;
  final String label;

  @override
  Widget build(BuildContext context) => SettingBuilder<bool>(
    settingKey: settingKey,
    builder: (context, on) => HaulToggle(
      value: on,
      semanticLabel: label,
      onChanged: (v) =>
          context.read<AppDependencies>().settings.set(settingKey, v),
    ),
  );
}

class GeneralPane extends StatelessWidget {
  const GeneralPane({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final deps = context.read<AppDependencies>();
    final settings = deps.settings;
    final bridge = deps.bridge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: 'Startup',
          children: [
            SettingsRow(
              label: 'Open Haul at login',
              help: 'Start Haul when you log in to your Mac.',
              control: SettingToggle(
                settingKey: _launchAtLogin,
                label: 'Open Haul at login',
              ),
            ),
            SettingsRow(
              label: 'Start hidden',
              help: 'Open with no window; Haul works from the menu bar.',
              control: SettingToggle(
                settingKey: _startHidden,
                label: 'Start hidden',
              ),
            ),
            SettingsRow(
              label: 'Resume downloads on launch',
              help: 'Carry on with downloads that were running when Haul quit.',
              control: SettingToggle(
                settingKey: _resumeOnLaunch,
                label: 'Resume downloads on launch',
              ),
            ),
            SettingsRow(
              label: 'Keep Mac awake while downloading',
              help: 'Stops your Mac sleeping until downloads finish.',
              control: SettingToggle(
                settingKey: _keepAwake,
                label: 'Keep Mac awake while downloading',
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'Browser integration',
          children: [
            SettingsRow(
              label: 'Take over downloads from browsers',
              help: 'Needs the Haul extension in your browser.',
              control: SettingToggle(
                settingKey: _browserIntegration,
                label: 'Take over downloads from browsers',
              ),
            ),
            SettingsRow(
              label: 'Status',
              control: BlocBuilder<BrowserStatusCubit, BrowserStatus>(
                builder: (context, s) => Text(
                  s == BrowserStatus.connected ? 'Connected' : 'Not paired',
                  style: theme.text.secondary,
                ),
              ),
            ),
            SettingsRow(
              label: 'Port',
              help:
                  'The extension talks to Haul on this port, on this Mac only.',
              control: SettingBuilder<int>(
                settingKey: _bridgePort,
                builder: (context, port) => SizedBox(
                  width: 100,
                  child: SyncedTextField(
                    label: 'Bridge port',
                    digitsOnly: true,
                    value: '$port',
                    // Only a port that is allowed is saved, so typing never
                    // restarts the bridge on a port that cannot work.
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n >= 1024 && n <= 65535) {
                        settings.set(Keys.bridgePort, n);
                      }
                    },
                  ),
                ),
              ),
            ),
            if (bridge != null)
              BlocBuilder<BridgeController, BridgeState>(
                bloc: bridge,
                builder: (context, s) => s.error == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: HaulSpace.half),
                        child: Text(
                          s.error!,
                          style: theme.text.caption.copyWith(
                            color: theme.colors.danger,
                          ),
                        ),
                      ),
              ),
            SettingsRow(
              label: 'Pairing token',
              help: 'Paste it into the extension once to pair it.',
              control: HaulButton(
                label: 'Copy token',
                icon: HaulIcons.copy,
                onPressed: () async {
                  final token = await settings.ensureBridgeToken();
                  await Clipboard.setData(ClipboardData(text: token));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

final _launchAtLogin = Keys.launchAtLogin;
final _startHidden = Keys.startHidden;
final _resumeOnLaunch = Keys.resumeOnLaunch;
final _keepAwake = Keys.keepAwake;
final _browserIntegration = Keys.browserIntegrationEnabled;
final _bridgePort = Keys.bridgePort;
