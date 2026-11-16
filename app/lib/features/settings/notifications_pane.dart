import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/dependencies.dart';
import '../../app/theme/haul_theme.dart';
import '../../data/setting_key.dart';
import '../../data/setting_keys.dart';
import 'general_pane.dart';
import 'setting_builder.dart';
import 'settings_widgets.dart';

class NotificationsPane extends StatelessWidget {
  const NotificationsPane({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingBuilder<bool>(
      settingKey: Keys.notificationsEnabled,
      builder: (context, on) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSection(
            title: 'Notifications',
            children: [
              SettingsRow(
                label: 'Show notifications',
                help: 'Banners from Haul in the corner of your screen.',
                control: SettingToggle(
                  settingKey: Keys.notificationsEnabled,
                  label: 'Show notifications',
                ),
              ),
              _EventToggle(
                label: 'When a download finishes',
                settingKey: Keys.notifyOnComplete,
                enabled: on,
              ),
              _EventToggle(
                label: 'When a download fails',
                settingKey: Keys.notifyOnFailure,
                enabled: on,
              ),
            ],
          ),
          SettingsSection(
            title: 'Sounds',
            children: [
              _SoundRow(label: 'Download finished', settingKey: _complete),
              _SoundRow(label: 'Download failed', settingKey: _failed),
              _SoundRow(
                label: 'All downloads finished',
                help: 'When the queue runs empty.',
                settingKey: _queue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final _complete = Keys.soundOnComplete;
final _failed = Keys.soundOnFailure;
final _queue = Keys.soundOnQueueFinished;

class _EventToggle extends StatelessWidget {
  const _EventToggle({
    required this.label,
    required this.settingKey,
    required this.enabled,
  });

  final String label;
  final SettingKey<bool> settingKey;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !enabled,
        child: SettingsRow(
          label: label,
          control: SettingToggle(settingKey: settingKey, label: label),
        ),
      ),
    );
  }
}

/// One event's sound: a picker (with "None" for silence) and a button to hear
/// it.
class _SoundRow extends StatefulWidget {
  const _SoundRow({required this.label, required this.settingKey, this.help});

  final String label;
  final String? help;
  final SettingKey<String?> settingKey;

  @override
  State<_SoundRow> createState() => _SoundRowState();
}

class _SoundRowState extends State<_SoundRow> {
  List<String> _names = const [];

  @override
  void initState() {
    super.initState();
    context.read<AppDependencies>().sounds?.names().then((n) {
      if (mounted) setState(() => _names = n);
    });
  }

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDependencies>();
    return SettingBuilder<String?>(
      settingKey: widget.settingKey,
      builder: (context, chosen) {
        // A sound that has gone from the system is still shown, so the
        // setting is never silently changed.
        final names = {..._names, ?chosen}.toList()..sort();
        return SettingsRow(
          label: widget.label,
          help: widget.help,
          control: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HaulDropdown<String>(
                width: 150,
                value: chosen ?? _none,
                items: [
                  const HaulDropdownItem(_none, 'None'),
                  for (final n in names) HaulDropdownItem(n, n),
                ],
                onChanged: (v) =>
                    deps.settings.set(widget.settingKey, v == _none ? null : v),
              ),
              const SizedBox(width: HaulSpace.s),
              HaulIconButton(
                icon: HaulIcons.play,
                tooltip: 'Play ${widget.label} sound',
                onPressed: chosen == null
                    ? null
                    : () => deps.sounds?.play(chosen),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The dropdown needs a value for "None"; no sound has this name.
  static const _none = '';
}
