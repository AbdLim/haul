import 'package:download_engine/download_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haul/app/cubits/shell_cubit.dart';

void main() {
  late ShellCubit cubit;
  setUp(() => cubit = ShellCubit());
  tearDown(() => cubit.close());

  test('starts on the download list with no filter', () {
    expect(cubit.state.section, MainSection.downloads);
    expect(cubit.state.status, StatusFilter.all);
    expect(cubit.state.categoryId, isNull);
    expect(cubit.state.selection, isEmpty);
    expect(cubit.state.detailId, isNull);
  });

  test('settings replaces the list and can be left again', () {
    cubit.showSettings();
    expect(cubit.state.section, MainSection.settings);
    cubit.toggleSettings();
    expect(cubit.state.section, MainSection.downloads);
    cubit.toggleSettings();
    expect(cubit.state.section, MainSection.settings);
    cubit.showDownloads();
    expect(cubit.state.section, MainSection.downloads);
  });

  test('a status filter and a category filter exclude each other', () {
    cubit.filterByCategory(3);
    expect(cubit.state.categoryId, 3);
    expect(cubit.state.status, StatusFilter.all);

    cubit.filterByStatus(StatusFilter.paused);
    expect(cubit.state.status, StatusFilter.paused);
    expect(cubit.state.categoryId, isNull);

    cubit.filterByCategory(5);
    expect(cubit.state.status, StatusFilter.all);
    expect(cubit.state.categoryId, 5);
  });

  test('choosing a filter leaves settings and clears the selection', () {
    cubit.select({'a'});
    cubit.showSettings();
    cubit.filterByStatus(StatusFilter.active);
    expect(cubit.state.section, MainSection.downloads);
    expect(cubit.state.selection, isEmpty);
  });

  test('the detail panel shows only for exactly one selected download', () {
    cubit.select({'a'});
    expect(cubit.state.detailId, 'a');
    cubit.select({'a', 'b'});
    expect(cubit.state.detailId, isNull);
    cubit.clearSelection();
    expect(cubit.state.detailId, isNull);
  });

  test('forget drops ids that no longer exist', () {
    cubit.select({'a', 'b', 'c'});
    cubit.forget({'a', 'c', 'z'});
    expect(cubit.state.selection, {'a', 'c'});
  });

  test('the Add URL dialog opens with an optional link', () {
    cubit.showSettings();
    cubit.openAddDialog(url: 'https://e.com/f.zip');
    expect(cubit.state.addDialogOpen, isTrue);
    expect(cubit.state.addDialogUrl, 'https://e.com/f.zip');
    expect(cubit.state.section, MainSection.downloads);
    cubit.closeAddDialog();
    expect(cubit.state.addDialogOpen, isFalse);
    expect(cubit.state.addDialogUrl, isNull);
    cubit.openAddDialog();
    expect(cubit.state.addDialogUrl, isNull);
  });

  test('search text is kept', () {
    cubit.setQuery('ubuntu');
    expect(cubit.state.query, 'ubuntu');
  });

  group('StatusFilter', () {
    test('groups the seven statuses the way the sidebar counts them', () {
      bool m(StatusFilter f, DownloadStatus s) => f.matches(s);
      for (final s in DownloadStatus.values) {
        expect(m(StatusFilter.all, s), isTrue);
      }
      for (final s in [
        DownloadStatus.queued,
        DownloadStatus.probing,
        DownloadStatus.downloading,
      ]) {
        expect(m(StatusFilter.active, s), isTrue, reason: s.name);
      }
      expect(m(StatusFilter.paused, DownloadStatus.paused), isTrue);
      expect(m(StatusFilter.completed, DownloadStatus.completed), isTrue);
      expect(m(StatusFilter.failed, DownloadStatus.failed), isTrue);
      expect(m(StatusFilter.failed, DownloadStatus.needsRefresh), isTrue);
      expect(m(StatusFilter.active, DownloadStatus.paused), isFalse);
      expect(m(StatusFilter.completed, DownloadStatus.failed), isFalse);
    });

    test('every status belongs to exactly one specific filter', () {
      const specific = [
        StatusFilter.active,
        StatusFilter.paused,
        StatusFilter.completed,
        StatusFilter.failed,
      ];
      for (final s in DownloadStatus.values) {
        expect(
          specific.where((f) => f.matches(s)),
          hasLength(1),
          reason: s.name,
        );
      }
    });
  });
}
