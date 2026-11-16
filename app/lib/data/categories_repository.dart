import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

class DownloadCategory {
  const DownloadCategory({
    required this.id,
    required this.name,
    required this.extensions,
    required this.saveDir,
    required this.sortOrder,
    required this.builtIn,
  });

  final int id;
  final String name;

  /// Lower-case, without the dot.
  final List<String> extensions;
  final String saveDir;
  final int sortOrder;
  final bool builtIn;

  DownloadCategory copyWith({List<String>? extensions, String? saveDir}) =>
      DownloadCategory(
        id: id,
        name: name,
        extensions: extensions ?? this.extensions,
        saveDir: saveDir ?? this.saveDir,
        sortOrder: sortOrder,
        builtIn: builtIn,
      );
}

/// Name and default extensions of the six built-in categories, in order.
/// "Other" takes everything that matches nothing else.
const builtInCategories = <(String, List<String>)>[
  ('Compressed', ['zip', 'rar', '7z', 'tar', 'gz']),
  ('Documents', ['pdf', 'epub', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx']),
  ('Music', ['mp3', 'flac', 'wav', 'aac', 'm4a']),
  ('Video', ['mp4', 'mkv', 'mov', 'avi', 'webm']),
  ('Programs', ['dmg', 'pkg', 'iso', 'exe', 'msi', 'apk']),
  ('Other', <String>[]),
];

const otherCategoryName = 'Other';

/// The categories, their folders, and which category a file belongs to.
class CategoriesRepository {
  CategoriesRepository(this._db);

  final HaulDatabase _db;

  /// Creates the six built-in categories if there are none. Each defaults to
  /// a folder of its own name inside [downloadsDir], except Other, which uses
  /// [downloadsDir] itself. Safe to call on every launch.
  Future<void> ensureBuiltIns(String downloadsDir) async {
    final existing = await _db.select(_db.categories).get();
    final have = {for (final c in existing) c.name};
    var order = 0;
    for (final (name, extensions) in builtInCategories) {
      if (!have.contains(name)) {
        await _db
            .into(_db.categories)
            .insert(
              CategoriesCompanion.insert(
                name: name,
                extensions: Value(jsonEncode(extensions)),
                saveDir: name == otherCategoryName
                    ? downloadsDir
                    : '$downloadsDir/$name',
                sortOrder: Value(order),
                builtIn: const Value(true),
              ),
            );
      }
      order++;
    }
  }

  Future<List<DownloadCategory>> all() async {
    final rows = await (_db.select(
      _db.categories,
    )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
    return [for (final r in rows) _from(r)];
  }

  Stream<List<DownloadCategory>> watchAll() {
    final query = _db.select(_db.categories)
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    return query.watch().map((rows) => [for (final r in rows) _from(r)]);
  }

  /// Which category a file belongs to, by extension. Names that match no
  /// category, or that have no extension, go to Other.
  Future<DownloadCategory> categoryFor(String fileName) async {
    final categories = await all();
    final ext = extensionOf(fileName);
    if (ext != null) {
      for (final c in categories) {
        if (c.extensions.contains(ext)) return c;
      }
    }
    return categories.firstWhere((c) => c.name == otherCategoryName);
  }

  /// The save folder for a file: its category's folder. Only new downloads
  /// use this; a download already added keeps the folder it was given.
  Future<String> saveDirFor(String fileName) async =>
      (await categoryFor(fileName)).saveDir;

  Future<void> setSaveDir(int id, String saveDir) =>
      (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(saveDir: Value(saveDir)),
      );

  Future<void> setExtensions(int id, List<String> extensions) =>
      (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(
          extensions: Value(
            jsonEncode([for (final e in extensions) cleanExtension(e)]),
          ),
        ),
      );

  /// Puts one category back to its built-in extensions and folder.
  Future<void> resetBuiltIn(int id, String downloadsDir) async {
    final row = await (_db.select(
      _db.categories,
    )..where((t) => t.id.equals(id))).getSingle();
    final def = builtInCategories.firstWhere((c) => c.$1 == row.name);
    await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        extensions: Value(jsonEncode(def.$2)),
        saveDir: Value(
          row.name == otherCategoryName
              ? downloadsDir
              : '$downloadsDir/${row.name}',
        ),
      ),
    );
  }

  /// `report.PDF` gives `pdf`; `archive.tar.gz` gives `gz`; `README` gives
  /// null.
  static String? extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return null;
    return fileName.substring(dot + 1).toLowerCase();
  }

  /// "  .PDF" becomes "pdf".
  static String cleanExtension(String e) =>
      e.trim().toLowerCase().replaceFirst(RegExp(r'^\.+'), '');

  DownloadCategory _from(CategoryRow r) => DownloadCategory(
    id: r.id,
    name: r.name,
    extensions: (jsonDecode(r.extensions) as List<Object?>).cast<String>(),
    saveDir: r.saveDir,
    sortOrder: r.sortOrder,
    builtIn: r.builtIn,
  );
}
