import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/cubits/browser_status_cubit.dart';
import '../../app/dependencies.dart';
import '../../app/theme/haul_theme.dart';
import '../../data/setting_keys.dart';
import '../settings/setting_builder.dart';

/// Shown on a fresh install until a browser extension connects or the card is
/// closed. It walks through the three steps of pairing a browser.
class FirstRunCard extends StatelessWidget {
  const FirstRunCard({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.read<AppDependencies>().settings;
    return BlocListener<BrowserStatusCubit, BrowserStatus>(
      // A connected browser means the card has done its job.
      listener: (context, status) {
        if (status == BrowserStatus.connected) {
          settings.set(Keys.firstRunDismissed, true);
        }
      },
      child: SettingBuilder<bool>(
        settingKey: Keys.firstRunDismissed,
        builder: (context, dismissed) {
          final connected =
              context.watch<BrowserStatusCubit>().state ==
              BrowserStatus.connected;
          if (dismissed || connected) return const SizedBox.shrink();
          return _Card(
            onDismiss: () => settings.set(Keys.firstRunDismissed, true),
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    final settings = context.read<AppDependencies>().settings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HaulSpace.m,
        HaulSpace.s,
        HaulSpace.m,
        HaulSpace.s,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgSurface,
          borderRadius: BorderRadius.circular(HaulRadii.row),
          border: Border.all(color: theme.colors.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.all(HaulSpace.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Take over downloads from your browser',
                      style: theme.text.heading,
                    ),
                  ),
                  HaulIconButton(
                    icon: HaulIcons.close,
                    tooltip: 'Dismiss',
                    onPressed: onDismiss,
                  ),
                ],
              ),
              const SizedBox(height: HaulSpace.s),
              const _Step(1, 'Install the Haul extension in your browser.'),
              const _Step(
                2,
                'Open the extension\'s options and paste the pairing token.',
              ),
              const _Step(
                3,
                'Press Test connection. This card goes away once it works.',
              ),
              const SizedBox(height: HaulSpace.s),
              Row(
                children: [
                  HaulButton(
                    label: 'Copy token',
                    icon: HaulIcons.copy,
                    kind: HaulButtonKind.primary,
                    onPressed: () async {
                      final token = await settings.ensureBridgeToken();
                      await Clipboard.setData(ClipboardData(text: token));
                    },
                  ),
                  const SizedBox(width: HaulSpace.s),
                  HaulButton(
                    label: 'Not now',
                    kind: HaulButtonKind.ghost,
                    onPressed: onDismiss,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.text);
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text('$number', style: theme.text.numericSecondary),
          ),
          Expanded(child: Text(text, style: theme.text.body)),
        ],
      ),
    );
  }
}
