import 'package:download_engine/download_engine.dart';
import 'package:flutter/widgets.dart';

import '../../app/components/components.dart';
import '../../app/platform_names.dart';
import '../../data/downloads_dao.dart';

/// Everything that can be done to a download from its menu.
enum RowAction {
  pause,
  resume,
  retry,
  refreshLink,
  showInFinder,
  open,
  copyUrl,
  cancel,
  remove,
  deleteFile,
}

bool _running(StoredDownload d) =>
    d.snapshot.status.isActive || d.snapshot.status == DownloadStatus.queued;

/// The actions that make sense for [selection], in menu order. An action is
/// offered if it applies to at least one selected download, and is then
/// applied to just those it fits.
List<RowAction> availableActions(List<StoredDownload> selection) {
  if (selection.isEmpty) return const [];
  final single = selection.length == 1 ? selection.single : null;
  bool any(bool Function(StoredDownload) f) => selection.any(f);
  DownloadStatus st(StoredDownload d) => d.snapshot.status;

  return [
    if (any(_running)) RowAction.pause,
    if (any((d) => st(d) == DownloadStatus.paused)) RowAction.resume,
    if (any((d) => st(d) == DownloadStatus.failed)) RowAction.retry,
    if (single != null && st(single) == DownloadStatus.needsRefresh)
      RowAction.refreshLink,
    if (single != null) RowAction.showInFinder,
    if (single != null && st(single) == DownloadStatus.completed)
      RowAction.open,
    RowAction.copyUrl,
    if (any((d) => st(d) != DownloadStatus.completed)) RowAction.cancel,
    if (any((d) => !_running(d))) RowAction.remove,
    if (any((d) => st(d) == DownloadStatus.completed)) RowAction.deleteFile,
  ];
}

/// The downloads in [selection] that [action] applies to.
List<StoredDownload> appliesTo(
  RowAction action,
  List<StoredDownload> selection,
) {
  bool Function(StoredDownload) test = switch (action) {
    RowAction.pause => _running,
    RowAction.resume => (d) => d.snapshot.status == DownloadStatus.paused,
    RowAction.retry => (d) => d.snapshot.status == DownloadStatus.failed,
    RowAction.refreshLink => (
      d,
    ) => d.snapshot.status == DownloadStatus.needsRefresh,
    RowAction.open => (d) => d.snapshot.status == DownloadStatus.completed,
    RowAction.cancel => (d) => d.snapshot.status != DownloadStatus.completed,
    RowAction.remove => (d) => !_running(d),
    RowAction.deleteFile => (
      d,
    ) => d.snapshot.status == DownloadStatus.completed,
    RowAction.showInFinder || RowAction.copyUrl => (_) => true,
  };
  return [
    for (final d in selection)
      if (test(d)) d,
  ];
}

/// Downloads that would lose their progress if paused: the server does not
/// allow resuming, and some of the file has already arrived.
List<StoredDownload> losesProgressIfPaused(List<StoredDownload> downloads) => [
  for (final d in downloads)
    if (_running(d) && !d.snapshot.resumable && d.snapshot.downloadedBytes > 0)
      d,
];

/// The menu and button text for [a].
String rowActionLabel(RowAction a) => switch (a) {
  RowAction.pause => 'Pause',
  RowAction.resume => 'Resume',
  RowAction.retry => 'Retry',
  RowAction.refreshLink => 'Refresh link…',
  RowAction.showInFinder => 'Show in ${PlatformNames.fileManager}',
  RowAction.open => 'Open',
  RowAction.copyUrl => 'Copy URL',
  RowAction.cancel => 'Cancel download…',
  RowAction.remove => 'Remove from list',
  RowAction.deleteFile => 'Delete file…',
};

/// The icon for [a].
IconData rowActionIcon(RowAction a) => switch (a) {
  RowAction.pause => HaulIcons.pause,
  RowAction.resume => HaulIcons.play,
  RowAction.retry => HaulIcons.retry,
  RowAction.refreshLink => HaulIcons.link,
  RowAction.showInFinder => HaulIcons.folder,
  RowAction.open => HaulIcons.open,
  RowAction.copyUrl => HaulIcons.copy,
  RowAction.cancel => HaulIcons.close,
  RowAction.remove => HaulIcons.list,
  RowAction.deleteFile => HaulIcons.trash,
};

/// The context menu for [selection]. Each item calls [run] with its action.
List<HaulMenuEntry> buildRowMenu(
  List<StoredDownload> selection,
  void Function(RowAction action) run,
) {
  final actions = availableActions(selection);
  HaulMenuItem item(RowAction a) => HaulMenuItem(
    label: rowActionLabel(a),
    icon: rowActionIcon(a),
    destructive: a == RowAction.cancel || a == RowAction.deleteFile,
    onSelected: () => run(a),
  );
  List<HaulMenuEntry> group(List<RowAction> members) => [
    for (final a in members)
      if (actions.contains(a)) item(a),
  ];

  final groups = [
    group([
      RowAction.pause,
      RowAction.resume,
      RowAction.retry,
      RowAction.refreshLink,
    ]),
    group([RowAction.showInFinder, RowAction.open, RowAction.copyUrl]),
    group([RowAction.cancel, RowAction.remove, RowAction.deleteFile]),
  ].where((g) => g.isNotEmpty).toList();

  return [
    for (var i = 0; i < groups.length; i++) ...[
      if (i > 0) const HaulMenuDivider(),
      ...groups[i],
    ],
  ];
}
