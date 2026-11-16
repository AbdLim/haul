import 'package:download_engine/download_engine.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/add_download/browser_handoff.dart';

import '../../features/settings/settings_pane.dart';

/// Which of the two views fills the window.
enum MainSection { downloads, settings }

/// The sidebar's status filters.
enum StatusFilter {
  all,
  active,
  paused,
  completed,
  failed;

  bool matches(DownloadStatus s) => switch (this) {
    StatusFilter.all => true,
    StatusFilter.active =>
      s == DownloadStatus.queued ||
          s == DownloadStatus.probing ||
          s == DownloadStatus.downloading,
    StatusFilter.paused => s == DownloadStatus.paused,
    StatusFilter.completed => s == DownloadStatus.completed,
    StatusFilter.failed =>
      s == DownloadStatus.failed || s == DownloadStatus.needsRefresh,
  };
}

class ShellState extends Equatable {
  const ShellState({
    this.section = MainSection.downloads,
    this.settingsPane = SettingsPane.general,
    this.status = StatusFilter.all,
    this.categoryId,
    this.selection = const {},
    this.query = '',
    this.addDialogOpen = false,
    this.addDialogUrl,
    this.addDialogHandoff,
  });

  final MainSection section;

  /// Which pane Settings shows. It is remembered between visits.
  final SettingsPane settingsPane;
  final StatusFilter status;

  /// A category filter. Null means every category.
  final int? categoryId;
  final Set<String> selection;
  final String query;
  final bool addDialogOpen;

  /// A link to put in the Add URL dialog when it opens.
  final String? addDialogUrl;

  /// A download sent by the browser, for the dialog to confirm.
  final BrowserHandoff? addDialogHandoff;

  /// The detail panel shows when exactly one download is selected.
  String? get detailId => selection.length == 1 ? selection.first : null;

  ShellState copyWith({
    MainSection? section,
    SettingsPane? settingsPane,
    StatusFilter? status,
    int? categoryId,
    bool clearCategory = false,
    Set<String>? selection,
    String? query,
    bool? addDialogOpen,
    String? addDialogUrl,
    bool clearAddDialogUrl = false,
    BrowserHandoff? addDialogHandoff,
    bool clearAddDialogHandoff = false,
  }) => ShellState(
    section: section ?? this.section,
    settingsPane: settingsPane ?? this.settingsPane,
    status: status ?? this.status,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    selection: selection ?? this.selection,
    query: query ?? this.query,
    addDialogOpen: addDialogOpen ?? this.addDialogOpen,
    addDialogUrl: clearAddDialogUrl
        ? null
        : (addDialogUrl ?? this.addDialogUrl),
    addDialogHandoff: clearAddDialogHandoff
        ? null
        : (addDialogHandoff ?? this.addDialogHandoff),
  );

  @override
  List<Object?> get props => [
    section,
    settingsPane,
    status,
    categoryId,
    selection,
    query,
    addDialogOpen,
    addDialogUrl,
    addDialogHandoff?.id,
  ];
}

/// What the window is showing: which view, which filter, what is selected.
class ShellCubit extends Cubit<ShellState> {
  ShellCubit() : super(const ShellState());

  void showSettings({SettingsPane? pane}) =>
      emit(state.copyWith(section: MainSection.settings, settingsPane: pane));

  void selectPane(SettingsPane pane) =>
      emit(state.copyWith(settingsPane: pane));
  void showDownloads() => emit(state.copyWith(section: MainSection.downloads));

  void toggleSettings() =>
      state.section == MainSection.settings ? showDownloads() : showSettings();

  /// Picking a status filter clears the category filter, and the other way
  /// round, so only one is ever active.
  void filterByStatus(StatusFilter f) => emit(
    state.copyWith(
      section: MainSection.downloads,
      status: f,
      clearCategory: true,
      selection: const {},
    ),
  );

  void filterByCategory(int id) => emit(
    state.copyWith(
      section: MainSection.downloads,
      status: StatusFilter.all,
      categoryId: id,
      selection: const {},
    ),
  );

  void setQuery(String q) => emit(state.copyWith(query: q));

  void select(Set<String> ids) => emit(state.copyWith(selection: ids));
  void clearSelection() => emit(state.copyWith(selection: const {}));

  /// Drops selected ids that no longer exist.
  void forget(Set<String> existing) {
    final kept = state.selection.where(existing.contains).toSet();
    if (kept.length != state.selection.length) {
      emit(state.copyWith(selection: kept));
    }
  }

  void openAddDialog({String? url, BrowserHandoff? handoff}) => emit(
    state.copyWith(
      addDialogOpen: true,
      section: MainSection.downloads,
      addDialogUrl: url,
      clearAddDialogUrl: url == null,
      addDialogHandoff: handoff,
      clearAddDialogHandoff: handoff == null,
    ),
  );

  void closeAddDialog() => emit(
    state.copyWith(
      addDialogOpen: false,
      clearAddDialogUrl: true,
      clearAddDialogHandoff: true,
    ),
  );
}
