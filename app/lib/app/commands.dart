import 'package:flutter/widgets.dart';

import 'cubits/downloads_cubit.dart';
import 'cubits/shell_cubit.dart';

/// The things the menu bar and keyboard shortcuts can do. One place, so a
/// menu item and a button always behave the same.
class HaulCommands {
  HaulCommands({required this.shell, required this.downloads});

  final ShellCubit shell;
  final DownloadsCubit downloads;

  /// Opens the component gallery. Set by the app in debug builds only.
  VoidCallback? openGallery;

  void newDownload() => shell.openAddDialog();
  void openSettings() => shell.showSettings();
  void showDownloads() => shell.showDownloads();
  void pauseAll() => downloads.pauseAll();
  void resumeAll() => downloads.resumeAll();

  /// Command-V: into a text field if one has focus, otherwise open the Add
  /// URL dialog (the dialog prefills itself from the clipboard).
  void paste() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx != null && _editable(ctx)) {
      Actions.maybeInvoke(
        ctx,
        const PasteTextIntent(SelectionChangedCause.keyboard),
      );
    } else {
      shell.openAddDialog();
    }
  }

  void copy() => _toFocused(CopySelectionTextIntent.copy);
  void cut() => _toFocused(
    const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
  );
  void selectAll() =>
      _toFocused(const SelectAllTextIntent(SelectionChangedCause.keyboard));

  void _toFocused(Intent intent) {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx != null) Actions.maybeInvoke(ctx, intent);
  }

  static bool _editable(BuildContext context) =>
      context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null;
}
