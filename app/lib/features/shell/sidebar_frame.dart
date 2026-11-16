import 'package:flutter/widgets.dart';

import '../../app/haul_mark.dart';
import '../../app/theme/haul_theme.dart';
import 'shell_metrics.dart';

/// The top of the sidebar: the mark and wordmark, clear of the traffic
/// lights.
class SidebarBrand extends StatelessWidget {
  const SidebarBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HaulSpace.m,
        ShellMetrics.trafficLightsHeight,
        HaulSpace.m,
        HaulSpace.m,
      ),
      child: Row(
        children: [
          const HaulMark(size: 28),
          const SizedBox(width: HaulSpace.s),
          Text('Haul', style: theme.text.wordmark),
        ],
      ),
    );
  }
}
