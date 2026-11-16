import 'package:drift/drift.dart';

/// One row per download. Mirrors the engine's `DownloadSnapshot`.
@DataClassName('DownloadRow')
class Downloads extends Table {
  TextColumn get id => text()();
  TextColumn get url => text()();
  TextColumn get finalUrl => text().nullable()();
  TextColumn get fileName => text().nullable()();
  TextColumn get saveDir => text()();
  IntColumn get totalBytes => integer().nullable()();
  IntColumn get downloadedBytes => integer().withDefault(const Constant(0))();
  TextColumn get status => text()();
  BoolColumn get supportsRanges =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get resumable => boolean().withDefault(const Constant(true))();
  TextColumn get etag => text().nullable()();
  TextColumn get lastModified => text().nullable()();

  /// Content-Type from the probe. The engine snapshot carries it and the
  /// UI uses it for the file icon.
  TextColumn get contentType => text().nullable()();

  /// JSON: referrer, user agent, cookies and the file name the caller asked for.
  TextColumn get requestHeaders => text().withDefault(const Constant('{}'))();
  IntColumn get maxConnections => integer().withDefault(const Constant(8))();

  /// Which category chose the save folder. Null for downloads that predate
  /// categories or were saved somewhere by hand.
  IntColumn get categoryId => integer().nullable()();

  /// `manual`, `chrome` or `firefox`.
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The byte ranges of a download. Deleting a download deletes these.
@DataClassName('SegmentRow')
class Segments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get downloadId =>
      text().references(Downloads, #id, onDelete: KeyAction.cascade)();

  /// The engine's own id for the segment, unique within one download.
  IntColumn get segmentIndex => integer()();
  IntColumn get startOffset => integer()();
  IntColumn get endOffset => integer()();
  IntColumn get downloadedBytes => integer().withDefault(const Constant(0))();
  TextColumn get status => text()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {downloadId, segmentIndex},
  ];
}

/// Key and JSON value, for everything in Settings.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Compressed, Documents, Music, Video, Programs and Other, each with its own
/// save folder and the extensions that belong to it.
@DataClassName('CategoryRow')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();

  /// JSON list of lower-case extensions without the dot.
  TextColumn get extensions => text().withDefault(const Constant('[]'))();
  TextColumn get saveDir => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get builtIn => boolean().withDefault(const Constant(false))();
}

/// Per-site behaviour: a connection cap and a "never take over" switch.
@DataClassName('SiteRuleRow')
class SiteRules extends Table {
  TextColumn get host => text()();
  IntColumn get maxConnections => integer().nullable()();
  BoolColumn get neverIntercept =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {host};
}

/// Which sites have a stored login. The password is not here: it lives in
/// the macOS Keychain under `haul.login.<host>`.
@DataClassName('SiteLoginRow')
class SiteLogins extends Table {
  TextColumn get host => text()();
  TextColumn get username => text()();

  @override
  Set<Column<Object>> get primaryKey => {host};
}
