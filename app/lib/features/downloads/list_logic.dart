import '../../app/cubits/shell_cubit.dart';
import '../../data/downloads_dao.dart';

/// The downloads to show for the current filters, newest first.
///
/// A status filter and a category filter are never both active (the shell
/// cubit makes sure), and the search text narrows whichever is.
List<StoredDownload> visibleDownloads(
  List<StoredDownload> all,
  ShellState shell,
) {
  final query = shell.query.trim().toLowerCase();
  bool matchesQuery(StoredDownload d) {
    if (query.isEmpty) return true;
    final name = (d.snapshot.fileName ?? d.snapshot.request.fileName ?? '')
        .toLowerCase();
    return name.contains(query) ||
        d.snapshot.request.url.toString().toLowerCase().contains(query);
  }

  bool matchesFilter(StoredDownload d) {
    final categoryId = shell.categoryId;
    if (categoryId != null) return d.categoryId == categoryId;
    return shell.status.matches(d.snapshot.status);
  }

  return [
    for (final d in all.reversed)
      if (matchesFilter(d) && matchesQuery(d)) d,
  ];
}

/// The result of clicking a row.
class SelectionResult {
  const SelectionResult(this.selection, this.anchor);
  final Set<String> selection;

  /// The row a Shift-click extends from.
  final String? anchor;
}

/// Standard list selection:
///
/// * a plain click selects just that row;
/// * Command-click adds or removes that row;
/// * Shift-click selects everything from the anchor to that row, in the order
///   shown.
SelectionResult clickRow({
  required List<String> order,
  required Set<String> current,
  required String? anchor,
  required String clicked,
  required bool command,
  required bool shift,
}) {
  if (shift && anchor != null && order.contains(anchor)) {
    final from = order.indexOf(anchor);
    final to = order.indexOf(clicked);
    if (to >= 0) {
      final lo = from < to ? from : to;
      final hi = from < to ? to : from;
      final range = order.sublist(lo, hi + 1).toSet();
      // Command and Shift together add the range to what is selected.
      return SelectionResult(command ? {...current, ...range} : range, anchor);
    }
  }
  if (command) {
    final next = {...current};
    if (!next.remove(clicked)) next.add(clicked);
    return SelectionResult(next, clicked);
  }
  return SelectionResult({clicked}, clicked);
}
