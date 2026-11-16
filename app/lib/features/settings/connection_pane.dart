import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/dependencies.dart';
import '../../app/theme/haul_theme.dart';
import '../../data/setting_keys.dart';
import '../../data/site_rules_repository.dart';
import 'general_pane.dart';
import 'setting_builder.dart';
import 'settings_widgets.dart';

const _kib = 1024;
const _mib = 1024 * 1024;

class ConnectionPane extends StatelessWidget {
  const ConnectionPane({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDependencies>();
    final settings = deps.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: 'Speed',
          children: [
            SettingsRow(
              label: 'Connections for each download',
              help: 'More connections are faster on most sites.',
              control: SettingBuilder<int>(
                settingKey: Keys.maxConnections,
                builder: (context, n) => HaulDropdown<int>(
                  width: 100,
                  value: n,
                  items: [
                    for (final v in {1, 2, 4, 8, 16, n}.toList()..sort())
                      HaulDropdownItem(v, '$v'),
                  ],
                  onChanged: (v) => settings.set(Keys.maxConnections, v),
                ),
              ),
            ),
            SettingsRow(
              label: 'Limit total speed',
              help: 'Shared by every download. Applies within a second or two.',
              control: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SpeedLimitField(),
                  const SizedBox(width: HaulSpace.m),
                  SettingToggle(
                    settingKey: Keys.speedLimitEnabled,
                    label: 'Limit total speed',
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'When things go wrong',
          children: [
            SettingsRow(
              label: 'Retry attempts',
              help:
                  'How many times a failing download tries again. '
                  'Applies the next time Haul starts.',
              control: SettingBuilder<int>(
                settingKey: Keys.retryAttempts,
                builder: (context, n) => HaulDropdown<int>(
                  width: 100,
                  value: n,
                  items: [
                    for (final v in {1, 3, 5, 8, 12, 20, n}.toList()..sort())
                      HaulDropdownItem(v, '$v'),
                  ],
                  onChanged: (v) => settings.set(Keys.retryAttempts, v),
                ),
              ),
            ),
            SettingsRow(
              label: 'Give up on a silent connection after',
              help: 'Applies the next time Haul starts.',
              control: SettingBuilder<int>(
                settingKey: Keys.stallTimeoutSeconds,
                builder: (context, n) => HaulDropdown<int>(
                  width: 120,
                  value: n,
                  items: [
                    for (final v in {10, 20, 30, 60, 120, n}.toList()..sort())
                      HaulDropdownItem(v, '$v seconds'),
                  ],
                  onChanged: (v) => settings.set(Keys.stallTimeoutSeconds, v),
                ),
              ),
            ),
          ],
        ),
        const _SiteLimits(),
      ],
    );
  }
}

/// The speed limit's number and its unit. The setting is in bytes a second.
class _SpeedLimitField extends StatefulWidget {
  const _SpeedLimitField();

  @override
  State<_SpeedLimitField> createState() => _SpeedLimitFieldState();
}

class _SpeedLimitFieldState extends State<_SpeedLimitField> {
  late final TextEditingController _controller;
  late int _unit;

  static String _number(int bytes, int unit) =>
      '${(bytes / unit).round()}'.replaceFirst(RegExp(r'^0$'), '');

  @override
  void initState() {
    super.initState();
    final bytes = context.read<AppDependencies>().settings.get(
      Keys.speedLimitBytesPerSec,
    );
    _unit = bytes >= _mib && bytes % _mib == 0 ? _mib : _kib;
    _controller = TextEditingController(text: _number(bytes, _unit));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final n = int.tryParse(_controller.text) ?? 0;
    if (n <= 0) return;
    context.read<AppDependencies>().settings.set(
      Keys.speedLimitBytesPerSec,
      n * _unit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 90,
          child: HaulTextField(
            controller: _controller,
            hint: 'Speed',
            semanticLabel: 'Speed limit',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => _save(),
          ),
        ),
        const SizedBox(width: HaulSpace.s),
        HaulDropdown<int>(
          width: 100,
          value: _unit,
          items: const [
            HaulDropdownItem(_kib, 'KB/s'),
            HaulDropdownItem(_mib, 'MB/s'),
          ],
          onChanged: (u) {
            setState(() => _unit = u);
            _save();
          },
        ),
      ],
    );
  }
}

/// Hosts with their own cap on connections.
class _SiteLimits extends StatefulWidget {
  const _SiteLimits();

  @override
  State<_SiteLimits> createState() => _SiteLimitsState();
}

class _SiteLimitsState extends State<_SiteLimits> {
  final _host = TextEditingController();
  int _cap = 2;

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  Future<void> _add(AppDependencies deps) async {
    final host = SiteRulesRepository.normalize(_host.text);
    if (host.isEmpty) return;
    final existing = (await deps.siteRules.all())
        .where((r) => r.host == host)
        .firstOrNull;
    await deps.siteRules.save(
      SiteRule(
        host: host,
        maxConnections: _cap,
        neverIntercept: existing?.neverIntercept ?? false,
      ),
    );
    _host.clear();
  }

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDependencies>();
    final theme = HaulTheme.of(context);
    return StreamBuilder<List<SiteRule>>(
      stream: deps.siteRules.watchAll(),
      builder: (context, snap) {
        final rules = [
          for (final r in snap.data ?? const <SiteRule>[])
            if (r.maxConnections != null) r,
        ];
        return SettingsSection(
          title: 'Sites with their own limit',
          children: [
            if (rules.isEmpty)
              Padding(
                padding: const EdgeInsets.all(HaulSpace.m),
                child: Text(
                  'No sites. A site with a limit never gets more connections '
                  'than that, whatever the setting above says.',
                  style: theme.text.caption,
                ),
              ),
            for (final r in rules)
              SettingsRow(
                label: r.host,
                control: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HaulDropdown<int>(
                      width: 140,
                      value: r.maxConnections,
                      items: [
                        for (final v in {
                          1,
                          2,
                          4,
                          8,
                          16,
                          r.maxConnections!,
                        }.toList()..sort())
                          HaulDropdownItem(
                            v,
                            v == 1 ? '1 connection' : '$v connections',
                          ),
                      ],
                      onChanged: (v) => deps.siteRules.save(
                        SiteRule(
                          host: r.host,
                          maxConnections: v,
                          neverIntercept: r.neverIntercept,
                        ),
                      ),
                    ),
                    const SizedBox(width: HaulSpace.s),
                    HaulIconButton(
                      icon: HaulIcons.trash,
                      tooltip: 'Remove ${r.host}',
                      onPressed: () => deps.siteRules.save(
                        SiteRule(
                          host: r.host,
                          neverIntercept: r.neverIntercept,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(HaulSpace.m),
              child: Row(
                children: [
                  Expanded(
                    child: HaulTextField(
                      controller: _host,
                      hint: 'Add a site, such as example.com',
                      semanticLabel: 'Site to limit',
                      onSubmitted: (_) => _add(deps),
                    ),
                  ),
                  const SizedBox(width: HaulSpace.s),
                  HaulDropdown<int>(
                    width: 140,
                    value: _cap,
                    items: [
                      for (final v in const [1, 2, 4, 8, 16])
                        HaulDropdownItem(
                          v,
                          v == 1 ? '1 connection' : '$v connections',
                        ),
                    ],
                    onChanged: (v) => setState(() => _cap = v),
                  ),
                  const SizedBox(width: HaulSpace.s),
                  HaulButton(label: 'Add', onPressed: () => _add(deps)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
