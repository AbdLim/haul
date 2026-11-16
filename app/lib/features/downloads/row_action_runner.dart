import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/components/components.dart';
import '../../app/cubits/downloads_cubit.dart';
import '../../app/dependencies.dart';
import '../../data/downloads_dao.dart';
import 'refresh_link_dialog.dart';
import 'row_actions.dart';
import 'row_text.dart';

String _count(int n, String one) => n == 1 ? one : '$n ${one}s';

/// Carries out [action] on the downloads in [selection] that it applies to.
///
/// Anything that destroys something asks first, and pausing a download that
/// cannot be resumed warns that it will start over.
Future<void> runRowAction(
  BuildContext context,
  RowAction action,
  List<StoredDownload> selection,
) async {
  final deps = context.read<AppDependencies>();
  final downloads = context.read<DownloadsCubit>();
  final targets = appliesTo(action, selection);
  if (targets.isEmpty) return;

  switch (action) {
    case RowAction.pause:
      final losing = losesProgressIfPaused(targets);
      if (losing.isNotEmpty) {
        final ok = await confirm(
          context,
          title: 'Pause and start over?',
          message: losing.length == 1
              ? '${rowTitle(losing.single.snapshot)} comes from a server that does not allow resuming. If you pause it now, it will start again from the beginning.'
              : '${losing.length} of these come from servers that do not allow resuming. If you pause them now, they will start again from the beginning.',
          confirmLabel: 'Pause anyway',
          cancelLabel: 'Keep downloading',
        );
        if (!ok) return;
      }
      for (final d in targets) {
        downloads.pause(d.id);
      }
    case RowAction.resume:
    case RowAction.retry:
      for (final d in targets) {
        downloads.resume(d.id);
      }
    case RowAction.refreshLink:
      final d = targets.single;
      final url = await showRefreshLinkDialog(
        context,
        fileName: rowTitle(d.snapshot),
      );
      if (url != null) deps.downloads.refreshUrl(d.id, url);
    case RowAction.showInFinder:
      final d = targets.single;
      await deps.platform.revealInFileManager(
        d.snapshot.finalPath != null && d.snapshot.status.isFinished
            ? d.snapshot.finalPath!
            : d.snapshot.request.saveDir,
      );
    case RowAction.open:
      final path = targets.single.snapshot.finalPath;
      if (path != null) await deps.platform.openFile(path);
    case RowAction.copyUrl:
      await Clipboard.setData(
        ClipboardData(
          text: [for (final d in targets) d.snapshot.request.url.toString()]
              .join('\n'),
        ),
      );
    case RowAction.cancel:
      final ok = await confirm(
        context,
        title: 'Cancel ${_count(targets.length, 'download')}?',
        message:
            'Anything already downloaded is deleted, and the ${targets.length == 1 ? 'download is' : 'downloads are'} removed from the list.',
        confirmLabel: 'Cancel download',
        cancelLabel: 'Keep',
      );
      if (!ok) return;
      for (final d in targets) {
        downloads.cancel(d.id);
      }
    case RowAction.remove:
      for (final d in targets) {
        downloads.remove(d.id);
      }
    case RowAction.deleteFile:
      final ok = await confirm(
        context,
        title: 'Delete ${_count(targets.length, 'file')}?',
        message:
            '${targets.length == 1 ? 'The file is' : 'The files are'} moved to the Trash and removed from the list.',
        confirmLabel: 'Move to Trash',
        cancelLabel: 'Keep',
      );
      if (!ok) return;
      for (final d in targets) {
        final path = d.snapshot.finalPath;
        if (path != null) await deps.platform.moveToTrash(path);
        downloads.remove(d.id);
      }
  }
}
