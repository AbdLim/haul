import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/cubits/downloads_cubit.dart';
import '../../app/cubits/shell_cubit.dart';
import '../../app/dependencies.dart';
import '../../data/setting_keys.dart';
import 'add_download_cubit.dart';
import 'add_download_dialog.dart';
import 'browser_handoff.dart';

/// Opens the Add URL dialog whenever the shell asks for it, from the menu,
/// Command-N, the Add URL button, Command-V or a dropped link.
class AddDownloadHost extends StatelessWidget {
  const AddDownloadHost({
    required this.deps,
    required this.child,
    this.readClipboard = true,
    super.key,
  });

  final AppDependencies deps;
  final Widget child;
  final bool readClipboard;

  Future<void> _open(
    BuildContext context,
    String? url,
    BrowserHandoff? handoff,
  ) async {
    final shell = context.read<ShellCubit>();
    final downloads = context.read<DownloadsCubit>();
    final categories = downloads.state.categories;
    final fallback =
        deps.settings.get(Keys.defaultSaveDir) ??
        (categories.isEmpty ? '' : categories.last.saveDir);

    final cubit = AddDownloadCubit(
      downloads: deps.downloads,
      settings: deps.settings,
      prober: deps.urlProber,
      picker: deps.folderPicker,
      categories: categories,
      existing: () => downloads.state.downloads,
      fallbackSaveDir: fallback,
      rememberFolder: deps.categories.setSaveDir,
      url: url ?? '',
      handoff: handoff,
    );
    await showHaulDialog<AddOutcome>(
      context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: AddDownloadDialog(
          categories: categories,
          readClipboard: readClipboard,
        ),
      ),
    );
    await cubit.close();
    shell.closeAddDialog();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ShellCubit, ShellState>(
      listenWhen: (a, b) => !a.addDialogOpen && b.addDialogOpen,
      listener: (context, state) =>
          _open(context, state.addDialogUrl, state.addDialogHandoff),
      child: child,
    );
  }
}
