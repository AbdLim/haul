import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/dependencies.dart';
import '../../data/categories_repository.dart';
import '../../data/setting_keys.dart';
import '../../data/site_rules_repository.dart';
import 'chip_list_editor.dart';
import 'setting_builder.dart';
import 'settings_widgets.dart';

class FileTypesPane extends StatelessWidget {
  const FileTypesPane({super.key});

  static const _sizes = <int, String>{
    0: 'Any size',
    102400: '100 KB',
    1048576: '1 MB',
    5242880: '5 MB',
    10485760: '10 MB',
    52428800: '50 MB',
  };

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDependencies>();
    final settings = deps.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: 'Files Haul takes over',
          children: [
            SettingBuilder<List<String>>(
              settingKey: Keys.interceptExtensions,
              builder: (context, list) => Padding(
                padding: const EdgeInsets.all(16),
                child: ChipListEditor(
                  values: list,
                  hint: 'Add an extension, such as iso',
                  semanticLabel: 'Add an extension',
                  onAdd: (text) {
                    final ext = CategoriesRepository.cleanExtension(text);
                    if (ext.isEmpty || list.contains(ext)) return;
                    settings.set(Keys.interceptExtensions, [...list, ext]);
                  },
                  onRemove: (ext) => settings.set(Keys.interceptExtensions, [
                    for (final e in list)
                      if (e != ext) e,
                  ]),
                ),
              ),
            ),
            SettingsRow(
              label: 'Smallest file to take over',
              help: 'Smaller downloads stay with the browser.',
              control: SettingBuilder<int>(
                settingKey: Keys.interceptMinBytes,
                builder: (context, bytes) => HaulDropdown<int>(
                  width: 140,
                  items: [
                    for (final e in {
                      ..._sizes,
                      if (!_sizes.containsKey(bytes)) bytes: _custom(bytes),
                    }.entries)
                      HaulDropdownItem(e.key, e.value),
                  ],
                  value: bytes,
                  onChanged: (v) => settings.set(Keys.interceptMinBytes, v),
                ),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'Sites Haul never takes downloads from',
          children: [
            StreamBuilder<List<SiteRule>>(
              stream: deps.siteRules.watchAll(),
              builder: (context, snap) {
                final rules = snap.data ?? const <SiteRule>[];
                final hosts = [
                  for (final r in rules)
                    if (r.neverIntercept) r.host,
                ];
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ChipListEditor(
                    values: hosts,
                    hint: 'Add a site, such as example.com',
                    semanticLabel: 'Add a site',
                    emptyText: 'No sites',
                    onAdd: (text) => _setExcluded(deps, text, true),
                    onRemove: (host) => _setExcluded(deps, host, false),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  static String _custom(int bytes) => bytes >= 1048576
      ? '${(bytes / 1048576).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).round()} KB';

  /// Turns "never take over" on or off for a host, keeping any connection cap
  /// it already has.
  static Future<void> _setExcluded(
    AppDependencies deps,
    String text,
    bool excluded,
  ) async {
    final host = SiteRulesRepository.hostFrom(text);
    if (host.isEmpty) return;
    // Read now, not from what is on screen, which may be a moment behind.
    final existing = (await deps.siteRules.all())
        .where((r) => r.host == host)
        .firstOrNull;
    await deps.siteRules.save(
      SiteRule(
        host: host,
        maxConnections: existing?.maxConnections,
        neverIntercept: excluded,
      ),
    );
  }
}
