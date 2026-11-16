import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/cubits/update_cubit.dart';
import '../../app/theme/haul_theme.dart';
import '../../app/version.dart';
import 'update_actions.dart';

/// "Haul 1.0.1 is available", above the download list, until it is dismissed,
/// skipped or installed.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UpdateCubit, UpdateState>(
      builder: (context, state) {
        final cubit = context.read<UpdateCubit>();
        final info = state.info;
        if (!cubit.showBanner || info == null) return const SizedBox.shrink();
        final theme = HaulTheme.of(context);
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
              border: Border.all(color: theme.colors.accent.withAlpha(0x80)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HaulSpace.m,
                vertical: HaulSpace.s + 2,
              ),
              child: Row(
                children: [
                  HaulIcon(HaulIcons.download, color: theme.colors.accent),
                  const SizedBox(width: HaulSpace.s + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Haul ${info.version} is available',
                          style: theme.text.bodyStrong,
                        ),
                        Text(
                          'You have $appVersion.',
                          style: theme.text.caption,
                        ),
                      ],
                    ),
                  ),
                  HaulButton(
                    label: "What's new",
                    onPressed: () => showWhatsNew(context, info),
                  ),
                  const SizedBox(width: HaulSpace.s),
                  HaulButton(
                    label: 'Download',
                    kind: HaulButtonKind.primary,
                    onPressed: () => downloadUpdate(context, info),
                  ),
                  const SizedBox(width: HaulSpace.s),
                  HaulIconButton(
                    icon: HaulIcons.close,
                    tooltip: 'Later',
                    onPressed: cubit.later,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
