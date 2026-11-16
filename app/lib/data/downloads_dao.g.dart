// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloads_dao.dart';

// ignore_for_file: type=lint
mixin _$DownloadsDaoMixin on DatabaseAccessor<HaulDatabase> {
  $DownloadsTable get downloads => attachedDatabase.downloads;
  $SegmentsTable get segments => attachedDatabase.segments;
  DownloadsDaoManager get managers => DownloadsDaoManager(this);
}

class DownloadsDaoManager {
  final _$DownloadsDaoMixin _db;
  DownloadsDaoManager(this._db);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db.attachedDatabase, _db.downloads);
  $$SegmentsTableTableManager get segments =>
      $$SegmentsTableTableManager(_db.attachedDatabase, _db.segments);
}
