import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/dependencies.dart';
import '../../data/categories_repository.dart';
import '../../data/setting_keys.dart';
import 'chip_list_editor.dart';
import 'folder_row.dart';
import 'general_pane.dart';
import 'setting_builder.dart';
import 'settings_widgets.dart';

class SaveToPane extends StatelessWidget {
  const SaveToPane({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDependencies>();
    final settings = deps.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: 'Folders',
          children: [
            SettingsRow(
              label: 'Remember the last folder for each category',
              help: 'A folder you pick in the Add dialog is used next time.',
              control: SettingToggle(
                settingKey: Keys.rememberLastFolderPerCategory,
                label: 'Remember the last folder for each category',
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'Default save folder',
          children: [
            SettingsRow(
              label: 'Folder for downloads that match no category',
              control: SettingBuilder<String?>(
                settingKey: Keys.defaultSaveDir,
                builder: (context, dir) => FolderControl(
                  path: dir,
                  placeholder: 'Downloads folder',
                  onChosen: (d) => settings.set(Keys.defaultSaveDir, d),
                ),
              ),
            ),
          ],
        ),
        StreamBuilder<List<DownloadCategory>>(
          stream: deps.categories.watchAll(),
          builder: (context, snap) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final c in snap.data ?? const <DownloadCategory>[])
                _CategoryBlock(category: c, deps: deps),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock({required this.category, required this.deps});

  final DownloadCategory category;
  final AppDependencies deps;

  @override
  Widget build(BuildContext context) {
    final c = category;
    return SettingsSection(
      title: c.name,
      children: [
        SettingsRow(
          label: 'Save to',
          control: FolderControl(
            path: c.saveDir,
            onChosen: (dir) => deps.categories.setSaveDir(c.id, dir),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: c.name == otherCategoryName
              ? const SizedBox.shrink()
              : ChipListEditor(
                  values: c.extensions,
                  hint: 'Add an extension to ${c.name}',
                  semanticLabel: 'Add an extension to ${c.name}',
                  onAdd: (text) {
                    final ext = CategoriesRepository.cleanExtension(text);
                    if (ext.isEmpty || c.extensions.contains(ext)) return;
                    deps.categories.setExtensions(c.id, [...c.extensions, ext]);
                  },
                  onRemove: (ext) => deps.categories.setExtensions(c.id, [
                    for (final e in c.extensions)
                      if (e != ext) e,
                  ]),
                ),
        ),
      ],
    );
  }
}
