import 'dart:async';
import 'dart:convert';

import 'package:download_engine/download_engine.dart';
import 'package:drift/drift.dart';

import 'database.dart';
import 'tables.dart';

part 'downloads_dao.g.dart';

/// A download as stored: the engine snapshot plus what only the app knows.
class StoredDownload {
  const StoredDownload({
    required this.snapshot,
    required this.source,
    required this.createdAt,
    this.completedAt,
    this.categoryId,
  });

  final DownloadSnapshot snapshot;

  /// `manual`, `chrome` or `firefox`.
  final String source;
  final DateTime createdAt;
  final DateTime? completedAt;

  /// The category that picked this download's folder, if any.
  final int? categoryId;

  String get id => snapshot.id;
}

@DriftAccessor(tables: [Downloads, Segments])
class DownloadsDao extends DatabaseAccessor<HaulDatabase>
    with _$DownloadsDaoMixin {
  DownloadsDao(super.db);

  /// Inserts or replaces a download and its segments in one transaction.
  Future<void> save(
    DownloadSnapshot s, {
    String source = 'manual',
    DateTime? createdAt,
    DateTime? completedAt,
    int? categoryId,
  }) {
    return transaction(() async {
      final existing = await (select(
        downloads,
      )..where((t) => t.id.equals(s.id))).getSingleOrNull();
      final created = existing?.createdAt ?? createdAt ?? DateTime.now();
      final done = s.status == DownloadStatus.completed
          ? (existing?.completedAt ?? completedAt ?? DateTime.now())
          : null;

      await into(downloads).insertOnConflictUpdate(
        DownloadsCompanion.insert(
          id: s.id,
          url: s.request.url.toString(),
          finalUrl: Value(s.finalUrl?.toString()),
          fileName: Value(s.fileName),
          saveDir: s.request.saveDir,
          totalBytes: Value(s.totalBytes),
          downloadedBytes: Value(s.downloadedBytes),
          status: s.status.name,
          supportsRanges: Value(s.supportsRanges),
          resumable: Value(s.resumable),
          etag: Value(s.etag),
          lastModified: Value(s.lastModified),
          contentType: Value(s.contentType),
          requestHeaders: Value(_encodeHeaders(s.request)),
          maxConnections: Value(s.request.maxConnections),
          source: Value(existing?.source ?? source),
          categoryId: Value(existing?.categoryId ?? categoryId),
          errorCode: Value(s.error?.code.name),
          errorMessage: Value(s.error?.message),
          createdAt: created,
          completedAt: Value(done),
        ),
      );

      await (delete(segments)..where((t) => t.downloadId.equals(s.id))).go();
      await batch((b) {
        b.insertAll(segments, [
          for (final seg in s.segments)
            SegmentsCompanion.insert(
              downloadId: s.id,
              segmentIndex: seg.id,
              startOffset: seg.start,
              endOffset: seg.end,
              downloadedBytes: Value(seg.downloaded),
              status: seg.status.name,
            ),
        ]);
      });
    });
  }

  Future<StoredDownload?> byId(String id) async {
    final row = await (select(
      downloads,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    final segs = await _segmentsFor([id]);
    return _toStored(row, segs[id] ?? const []);
  }

  /// Every download, oldest first.
  Future<List<StoredDownload>> all() async {
    final rows = await (select(
      downloads,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
    final segs = await _segmentsFor([for (final r in rows) r.id]);
    return [for (final r in rows) _toStored(r, segs[r.id] ?? const [])];
  }

  /// Emits the full list now and again whenever a download or one of its
  /// segments changes.
  Stream<List<StoredDownload>> watchAll() => _watch(all);

  Stream<StoredDownload?> watchOne(String id) => _watch(() => byId(id));

  /// Re-reads [read] whenever the downloads or segments tables change.
  /// Reads never overlap, and cancelling the subscription is immediate.
  Stream<T> _watch<T>(Future<T> Function() read) {
    late final StreamController<T> controller;
    StreamSubscription<Set<TableUpdate>>? updates;
    var reading = false;
    var dirty = false;

    Future<void> refresh() async {
      if (reading) {
        dirty = true;
        return;
      }
      reading = true;
      do {
        dirty = false;
        try {
          final value = await read();
          if (!controller.isClosed) controller.add(value);
        } on Object catch (e, st) {
          if (!controller.isClosed) controller.addError(e, st);
        }
      } while (dirty && !controller.isClosed);
      reading = false;
    }

    controller = StreamController<T>(
      onListen: () {
        updates = db
            .tableUpdates(TableUpdateQuery.onAllTables([downloads, segments]))
            .listen((_) => refresh());
        unawaited(refresh());
      },
      onCancel: () async {
        await updates?.cancel();
      },
    );
    return controller.stream;
  }

  Future<void> deleteById(String id) =>
      (delete(downloads)..where((t) => t.id.equals(id))).go();

  Future<Map<String, List<Segment>>> _segmentsFor(List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows =
        await (select(segments)
              ..where((t) => t.downloadId.isIn(ids))
              ..orderBy([(t) => OrderingTerm.asc(t.segmentIndex)]))
            .get();
    final out = <String, List<Segment>>{};
    for (final r in rows) {
      out
          .putIfAbsent(r.downloadId, () => [])
          .add(
            Segment(
              id: r.segmentIndex,
              start: r.startOffset,
              end: r.endOffset,
              downloaded: r.downloadedBytes,
              status: SegmentStatus.values.byName(r.status),
            ),
          );
    }
    return out;
  }

  StoredDownload _toStored(DownloadRow r, List<Segment> segs) {
    final h = (jsonDecode(r.requestHeaders) as Map<String, Object?>);
    final request = DownloadRequest(
      id: r.id,
      url: Uri.parse(r.url),
      saveDir: r.saveDir,
      fileName: h['requestedFileName'] as String?,
      referrer: h['referrer'] as String?,
      userAgent: h['userAgent'] as String?,
      cookies: h['cookies'] as String?,
      maxConnections: r.maxConnections,
    );
    final code = r.errorCode;
    return StoredDownload(
      snapshot: DownloadSnapshot(
        request: request,
        status: DownloadStatus.values.byName(r.status),
        finalUrl: r.finalUrl == null ? null : Uri.parse(r.finalUrl!),
        fileName: r.fileName,
        totalBytes: r.totalBytes,
        supportsRanges: r.supportsRanges,
        resumable: r.resumable,
        etag: r.etag,
        lastModified: r.lastModified,
        contentType: r.contentType,
        segments: segs,
        error: code == null
            ? null
            : DownloadError(
                DownloadErrorCode.values.byName(code),
                r.errorMessage ?? '',
              ),
      ),
      source: r.source,
      createdAt: r.createdAt,
      completedAt: r.completedAt,
      categoryId: r.categoryId,
    );
  }

  String _encodeHeaders(DownloadRequest r) => jsonEncode({
    'requestedFileName': r.fileName,
    'referrer': r.referrer,
    'userAgent': r.userAgent,
    'cookies': r.cookies,
  });
}
