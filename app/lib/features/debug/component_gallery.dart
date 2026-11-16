import 'package:flutter/widgets.dart';

import '../../app/components/components.dart';
import '../../app/theme/haul_theme.dart';
import '../../data/setting_keys.dart';

/// Every component in both themes at once, for looking at and for golden
/// tests. Only reachable from the debug build's View menu.
class ComponentGallery extends StatelessWidget {
  const ComponentGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HaulTheme.dark.colors.bgWindow,
      child: Row(
        children: [
          for (final mode in [AppThemeMode.dark, AppThemeMode.light])
            Expanded(
              child: HaulThemeScope(
                mode: mode,
                duration: Duration.zero,
                child: GalleryPanel(mode: mode),
              ),
            ),
        ],
      ),
    );
  }
}

/// One theme's worth of the gallery.
class GalleryPanel extends StatefulWidget {
  const GalleryPanel({required this.mode, super.key});
  final AppThemeMode mode;

  @override
  State<GalleryPanel> createState() => _GalleryPanelState();
}

class _GalleryPanelState extends State<GalleryPanel> {
  bool _toggle = true;
  bool _check = true;
  double _slider = 0.4;
  String _segment = 'all';
  String? _choice = 'zip';
  final _field = TextEditingController(text: 'https://example.com/file.zip');

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Widget _section(HaulTheme theme, String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: HaulSpace.m),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: theme.text.caption),
        const SizedBox(height: HaulSpace.s),
        child,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    return ColoredBox(
      color: theme.colors.bgWindow,
      child: Padding(
        padding: const EdgeInsets.all(HaulSpace.l),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.mode == AppThemeMode.dark ? 'Dark' : 'Light',
                style: theme.text.viewTitle,
              ),
              const SizedBox(height: HaulSpace.m),
              _section(
                theme,
                'Buttons',
                Wrap(
                  spacing: HaulSpace.s,
                  runSpacing: HaulSpace.s,
                  children: [
                    HaulButton(
                      label: 'Add URL',
                      icon: HaulIcons.plus,
                      kind: HaulButtonKind.primary,
                      onPressed: () {},
                    ),
                    HaulButton(label: 'Secondary', onPressed: () {}),
                    HaulButton(
                      label: 'Ghost',
                      kind: HaulButtonKind.ghost,
                      onPressed: () {},
                    ),
                    const HaulButton(label: 'Disabled', onPressed: null),
                    HaulIconButton(
                      icon: HaulIcons.pause,
                      tooltip: 'Pause',
                      onPressed: () {},
                    ),
                    const HaulIconButton(
                      icon: HaulIcons.trash,
                      tooltip: 'Delete',
                      onPressed: null,
                    ),
                  ],
                ),
              ),
              _section(
                theme,
                'Text fields',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HaulTextField(
                      controller: _field,
                      leading: HaulIcon(
                        HaulIcons.link,
                        color: theme.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: HaulSpace.s),
                    const HaulTextField(hint: 'Search downloads'),
                    const SizedBox(height: HaulSpace.s),
                    const HaulTextField(hint: 'Not a link', invalid: true),
                    const SizedBox(height: HaulSpace.s),
                    const HaulTextField(hint: 'Disabled', enabled: false),
                  ],
                ),
              ),
              _section(
                theme,
                'Switches and boxes',
                Wrap(
                  spacing: HaulSpace.m,
                  runSpacing: HaulSpace.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    HaulToggle(
                      value: _toggle,
                      onChanged: (v) => setState(() => _toggle = v),
                    ),
                    HaulToggle(value: false, onChanged: (_) {}),
                    const HaulToggle(value: true, onChanged: null),
                    HaulCheckbox(
                      value: _check,
                      label: 'Resume on launch',
                      onChanged: (v) => setState(() => _check = v),
                    ),
                    HaulCheckbox(value: false, onChanged: (_) {}),
                  ],
                ),
              ),
              _section(
                theme,
                'Slider and segments',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 260,
                      child: HaulSlider(
                        value: _slider,
                        onChanged: (v) => setState(() => _slider = v),
                      ),
                    ),
                    const SizedBox(height: HaulSpace.s),
                    HaulSegmentedControl<String>(
                      segments: const [
                        HaulSegment('all', 'All'),
                        HaulSegment('dark', 'Dark'),
                        HaulSegment('light', 'Light'),
                      ],
                      value: _segment,
                      onChanged: (v) => setState(() => _segment = v),
                    ),
                  ],
                ),
              ),
              _section(
                theme,
                'Dropdown and chips',
                Wrap(
                  spacing: HaulSpace.s,
                  runSpacing: HaulSpace.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    HaulDropdown<String>(
                      width: 140,
                      value: _choice,
                      items: const [
                        HaulDropdownItem('zip', 'Compressed'),
                        HaulDropdownItem('mp4', 'Video'),
                        HaulDropdownItem('pdf', 'Documents'),
                      ],
                      onChanged: (v) => setState(() => _choice = v),
                    ),
                    HaulChip(label: 'zip', onDeleted: () {}),
                    HaulChip(label: 'dmg', onDeleted: () {}, selected: true),
                    const HaulChip(label: 'plain'),
                  ],
                ),
              ),
              _section(
                theme,
                'Progress',
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HaulProgressBar(value: 0.4),
                    SizedBox(height: HaulSpace.s),
                    HaulProgressBar(value: 1, tone: HaulProgressTone.success),
                    SizedBox(height: HaulSpace.s),
                    HaulProgressBar(value: 0.7, tone: HaulProgressTone.danger),
                    SizedBox(height: HaulSpace.s),
                    HaulProgressBar(value: 0.2, tone: HaulProgressTone.neutral),
                  ],
                ),
              ),
              _section(
                theme,
                'Dialog and menu',
                Wrap(
                  spacing: HaulSpace.s,
                  children: [
                    HaulButton(
                      label: 'Open dialog',
                      onPressed: () => showHaulDialog<void>(
                        context,
                        builder: (ctx) => HaulDialog(
                          title: 'Remove download?',
                          actions: [
                            HaulButton(
                              label: 'Cancel',
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                            HaulButton(
                              label: 'Remove',
                              kind: HaulButtonKind.primary,
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                          child: Text(
                            'The file stays on disk.',
                            style: theme.text.secondary,
                          ),
                        ),
                      ),
                    ),
                    HaulContextMenuRegion(
                      entriesBuilder: (_) => [
                        HaulMenuItem(
                          label: 'Show in Finder',
                          icon: HaulIcons.folder,
                          onSelected: () {},
                        ),
                        HaulMenuItem(
                          label: 'Copy URL',
                          icon: HaulIcons.copy,
                          shortcut: '⌘C',
                          onSelected: () {},
                        ),
                        const HaulMenuDivider(),
                        HaulMenuItem(
                          label: 'Delete file',
                          icon: HaulIcons.trash,
                          destructive: true,
                          onSelected: () {},
                        ),
                      ],
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colors.borderSubtle),
                          borderRadius: BorderRadius.circular(
                            HaulRadii.control,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(
                            'Right-click me',
                            style: theme.text.secondary,
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
}
