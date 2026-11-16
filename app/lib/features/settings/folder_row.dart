import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/dependencies.dart';
import '../../app/theme/haul_theme.dart';

/// A folder path with a "Choose…" button that opens the system's chooser.
class FolderControl extends StatelessWidget {
  const FolderControl({
    required this.path,
    required this.onChosen,
    this.placeholder = 'Not set',
    super.key,
  });

  final String? path;
  final ValueChanged<String> onChosen;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final theme = HaulTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(
            path ?? placeholder,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.ltr,
            style: theme.text.secondary,
          ),
        ),
        const SizedBox(width: HaulSpace.s),
        HaulButton(
          label: 'Choose…',
          onPressed: () async {
            final picked = await context
                .read<AppDependencies>()
                .folderPicker
                .pick(startIn: path);
            if (picked != null) onChosen(picked);
          },
        ),
      ],
    );
  }
}
