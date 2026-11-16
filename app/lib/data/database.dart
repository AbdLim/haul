import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'downloads_dao.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Downloads, Segments, Settings, Categories, SiteRules, SiteLogins],
  daos: [DownloadsDao],
)
class HaulDatabase extends _$HaulDatabase {
  HaulDatabase(super.executor);

  /// A throwaway database for tests.
  HaulDatabase.inMemory() : super(NativeDatabase.memory());

  /// The real database, a single file in the app support folder.
  factory HaulDatabase.file(File file) {
    file.parent.createSync(recursive: true);
    return HaulDatabase(NativeDatabase.createInBackground(file));
  }

  /// Bump when a table changes and add the step to [migration].
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // One `if (from < N)` block per schema version.
      if (from < 2) {
        // Version 2: categories, site rules, site logins, and a category
        // on each download.
        await m.createTable(categories);
        await m.createTable(siteRules);
        await m.createTable(siteLogins);
        await m.addColumn(downloads, downloads.categoryId);
      }
    },
    beforeOpen: (details) async {
      // SQLite ignores foreign keys unless asked; segments depend on
      // ON DELETE CASCADE.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
