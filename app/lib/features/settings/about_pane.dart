import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/dependencies.dart';
import '../../app/haul_mark.dart';
import '../../app/theme/haul_theme.dart';
import '../../app/version.dart';
import '../../data/setting_keys.dart';
import 'settings_widgets.dart';
import 'updates_section.dart';

class AboutPane extends StatelessWidget {
  const AboutPane({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: HaulSpace.l),
          child: Row(
            children: [
              const HaulMark(size: 56),
              const SizedBox(width: HaulSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Haul', style: theme.text.viewTitle),
                    const SizedBox(height: 2),
                    Text(
                      'A fast, open-source download manager for the Mac.',
                      style: theme.text.secondary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Version $appVersion · Free software under the GNU GPL v3 or later',
                      style: theme.text.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SettingsSection(
          title: 'Haul',
          children: [
            SettingsRow(
              label: 'Version',
              control: Text(appVersion, style: theme.text.numeric),
            ),
            SettingsRow(
              label: 'Help',
              help: 'How to add downloads, pair your browser and fix problems.',
              control: HaulButton(
                label: 'Open the guide',
                onPressed: () => _showText(
                  context,
                  'Using Haul',
                  rootBundle.loadString('assets/docs/GUIDE.md'),
                  markdown: true,
                ),
              ),
            ),
            SettingsRow(
              label: 'Licences',
              help: 'The fonts, icons and packages Haul is built from.',
              control: HaulButton(
                label: 'Show licences',
                onPressed: () =>
                    _showText(context, 'Licences', _collectLicences()),
              ),
            ),
          ],
        ),
        const UpdatesSection(),
        SettingsSection(
          title: 'Reset',
          children: [
            SettingsRow(
              label: 'Reset all settings',
              help:
                  'Puts every setting back to how it was at install. '
                  'Your downloads are not touched.',
              control: HaulButton(
                label: 'Reset all',
                onPressed: () => resetAllSettings(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Asks first, then puts every setting back to its default.
Future<void> resetAllSettings(BuildContext context) async {
  final settings = context.read<AppDependencies>().settings;
  final yes = await confirm(
    context,
    title: 'Reset all settings?',
    message:
        'Every setting goes back to its default. '
        'Your downloads and categories stay as they are.',
    confirmLabel: 'Reset all',
    cancelLabel: 'Cancel',
  );
  if (!yes) return;
  // The pairing token is not a preference: resetting it would silently
  // unpair the browser.
  await settings.reset([
    for (final k in Keys.all)
      if (k != Keys.bridgeToken) k,
  ]);
}

Future<String> _collectLicences() async {
  final out = StringBuffer();
  await for (final entry in LicenseRegistry.licenses) {
    out.writeln(entry.packages.join(', '));
    out.writeln();
    for (final p in entry.paragraphs) {
      out.writeln(p.text);
    }
    out.writeln('\n----\n');
  }
  return out.toString();
}

Future<void> _showText(
  BuildContext context,
  String title,
  Future<String> text, {
  bool markdown = false,
}) {
  return showHaulDialog<void>(
    context,
    builder: (ctx) {
      final theme = HaulTheme.of(ctx);
      return HaulDialog(
        title: title,
        width: markdown ? 680 : 560,
        actions: [
          HaulButton(
            label: 'Close',
            kind: HaulButtonKind.primary,
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
        child: SizedBox(
          height: markdown ? 480 : 360,
          child: FutureBuilder<String>(
            future: text,
            builder: (context, snap) => SingleChildScrollView(
              child: markdown && snap.hasData
                  ? Padding(
                      padding: const EdgeInsets.only(right: HaulSpace.s),
                      child: HaulMarkdown(snap.data!),
                    )
                  : Text(snap.data ?? 'Loading…', style: theme.text.caption),
            ),
          ),
        ),
      );
    },
  );
}
