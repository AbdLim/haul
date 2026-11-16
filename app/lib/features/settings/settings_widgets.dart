import 'package:flutter/widgets.dart';

import '../../app/theme/haul_theme.dart';

/// A heading over a group of rows in a pane.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: HaulSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: HaulSpace.s),
            child: Text(title, style: theme.text.heading),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.bgSurface,
              borderRadius: BorderRadius.circular(HaulRadii.row),
              border: Border.all(color: theme.colors.borderSubtle),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Container(height: 1, color: theme.colors.borderSubtle),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One setting: a label, a line of help under it, and the control on the
/// right.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.label,
    required this.control,
    this.help,
    super.key,
  });

  final String label;
  final String? help;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HaulSpace.m,
        vertical: 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.text.body),
                if (help != null) ...[
                  const SizedBox(height: 2),
                  Text(help!, style: theme.text.caption),
                ],
              ],
            ),
          ),
          const SizedBox(width: HaulSpace.m),
          control,
        ],
      ),
    );
  }
}
