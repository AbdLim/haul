import 'package:flutter/widgets.dart';

import 'button.dart';
import 'dialog.dart';
import '../theme/haul_theme.dart';

/// Asks a yes-or-no question and returns true only if the answer is yes.
/// Escape, clicking outside, or the cancel button all mean no.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Keep',
}) async {
  final answer = await showHaulDialog<bool>(
    context,
    builder: (ctx) {
      final theme = HaulTheme.of(ctx);
      return HaulDialog(
        title: title,
        width: 400,
        actions: [
          HaulButton(
            label: cancelLabel,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          HaulButton(
            label: confirmLabel,
            kind: HaulButtonKind.primary,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
        child: Text(message, style: theme.text.secondary),
      );
    },
  );
  return answer ?? false;
}
