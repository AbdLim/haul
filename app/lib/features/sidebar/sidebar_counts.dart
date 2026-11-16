import 'package:equatable/equatable.dart';

import '../../app/cubits/shell_cubit.dart';
import '../../data/downloads_dao.dart';

/// The numbers beside each sidebar filter.
class SidebarCounts extends Equatable {
  const SidebarCounts({required this.byStatus, required this.byCategory});

  factory SidebarCounts.from(List<StoredDownload> downloads) {
    final status = {for (final f in StatusFilter.values) f: 0};
    final category = <int, int>{};
    for (final d in downloads) {
      for (final f in StatusFilter.values) {
        if (f.matches(d.snapshot.status)) status[f] = status[f]! + 1;
      }
      final id = d.categoryId;
      if (id != null) category[id] = (category[id] ?? 0) + 1;
    }
    return SidebarCounts(byStatus: status, byCategory: category);
  }

  final Map<StatusFilter, int> byStatus;
  final Map<int, int> byCategory;

  int ofStatus(StatusFilter f) => byStatus[f] ?? 0;
  int ofCategory(int id) => byCategory[id] ?? 0;

  @override
  List<Object?> get props => [byStatus, byCategory];
}
