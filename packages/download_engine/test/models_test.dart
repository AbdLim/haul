import 'dart:convert';

import 'package:download_engine/download_engine.dart';
import 'package:test/test.dart';

/// Pushes [json] through real JSON text so lossy types would show up.
Map<String, Object?> wire(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

final request = DownloadRequest(
  id: 'abc',
  url: Uri.parse('https://example.com/a%20b.zip?x=1'),
  saveDir: '/tmp/dl',
  fileName: 'a.zip',
  referrer: 'https://example.com/',
  userAgent: 'UA/1.0',
  cookies: 'a=b; c=d',
  maxConnections: 4,
);

final snapshot = DownloadSnapshot(
  request: request,
  status: DownloadStatus.paused,
  finalUrl: Uri.parse('https://cdn.example.com/a.zip?sig=1'),
  fileName: 'a (1).zip',
  totalBytes: 5000000,
  supportsRanges: true,
  resumable: true,
  etag: '"abc"',
  lastModified: 'Wed, 01 Jan 2025 00:00:00 GMT',
  contentType: 'application/zip',
  segments: const [
    Segment(
      id: 0,
      start: 0,
      end: 2499999,
      downloaded: 100,
      status: SegmentStatus.active,
    ),
    Segment(id: 1, start: 2500000, end: 4999999),
  ],
  error: const DownloadError(DownloadErrorCode.network, 'Offline'),
);

void main() {
  test('DownloadRequest round trips', () {
    final back = DownloadRequest.fromJson(wire(request.toJson()));
    expect(back.toJson(), request.toJson());
    expect(back.url, request.url);
  });

  test('DownloadRequest works with only the required fields', () {
    final r = DownloadRequest(
      id: 'x',
      url: Uri.parse('https://e.com/f'),
      saveDir: '/d',
    );
    final back = DownloadRequest.fromJson(wire(r.toJson()));
    expect(back.fileName, isNull);
    expect(back.maxConnections, 8);
  });

  test('Segment round trips and computes ranges', () {
    const s = Segment(
      id: 3,
      start: 10,
      end: 19,
      downloaded: 4,
      status: SegmentStatus.done,
    );
    expect(Segment.fromJson(wire(s.toJson())).toJson(), s.toJson());
    expect(s.length, 10);
    expect(s.remaining, 6);
    expect(s.nextByte, 14);
  });

  test('DownloadStatus names are stable', () {
    expect(DownloadStatus.values.map((s) => s.name), [
      'queued',
      'probing',
      'downloading',
      'paused',
      'completed',
      'failed',
      'needsRefresh',
    ]);
  });

  test('DownloadError round trips every code', () {
    for (final code in DownloadErrorCode.values) {
      final e = DownloadError(code, 'm');
      final back = DownloadError.fromJson(wire(e.toJson()));
      expect(back.code, code);
      expect(back.message, 'm');
    }
  });

  test('DownloadSnapshot round trips with every field set', () {
    final back = DownloadSnapshot.fromJson(wire(snapshot.toJson()));
    expect(back.toJson(), snapshot.toJson());
    expect(back.downloadedBytes, 100);
    expect(back.partPath, '/tmp/dl/a (1).zip.part');
  });

  test('DownloadSnapshot round trips when fresh', () {
    final fresh = DownloadSnapshot(request: request);
    final back = DownloadSnapshot.fromJson(wire(fresh.toJson()));
    expect(back.status, DownloadStatus.queued);
    expect(back.segments, isEmpty);
    expect(back.error, isNull);
    expect(back.finalPath, isNull);
  });

  group('commands', () {
    final commands = <EngineCommand>[
      AddCommand(request),
      AddCommand(request, snapshot: snapshot),
      const PauseCommand('a'),
      const ResumeCommand('a'),
      const CancelCommand('a'),
      const RemoveCommand('a'),
      RefreshUrlCommand(
        'a',
        Uri.parse('https://x.test/new'),
        referrer: 'r',
        cookies: 'c=1',
        userAgent: 'u',
      ),
      const SetLimitsCommand(
        maxConcurrentDownloads: 2,
        maxConnections: 16,
        speedLimitBytesPerSec: 0,
      ),
      const SetLimitsCommand(),
    ];

    for (final c in commands) {
      test('${c.runtimeType} round trips', () {
        final back = EngineCommand.fromJson(wire(c.toJson()));
        expect(back.runtimeType, c.runtimeType);
        expect(back.toJson(), c.toJson());
      });
    }

    test('unknown type is rejected', () {
      expect(
        () => EngineCommand.fromJson({'type': 'nope'}),
        throwsFormatException,
      );
    });
  });

  group('events', () {
    final events = <EngineEvent>[
      SnapshotEvent(snapshot),
      const ProgressEvent(
        id: 'a',
        downloadedBytes: 10,
        totalBytes: 100,
        bytesPerSecond: 1234.5,
        eta: Duration(seconds: 42),
        segmentBytes: [4, 6],
        segments: [
          Segment(
            id: 0,
            start: 0,
            end: 49,
            downloaded: 4,
            status: SegmentStatus.active,
          ),
          Segment(id: 1, start: 50, end: 99, downloaded: 6),
        ],
      ),
      const ProgressEvent(
        id: 'a',
        downloadedBytes: 10,
        bytesPerSecond: 0,
        segmentBytes: [10],
      ),
      const FileChangedEvent('a'),
      const RemovedEvent('a'),
    ];

    for (final e in events) {
      test('${e.runtimeType} round trips', () {
        final back = EngineEvent.fromJson(wire(e.toJson()));
        expect(back.runtimeType, e.runtimeType);
        expect(back.toJson(), e.toJson());
      });
    }

    test('unknown type is rejected', () {
      expect(
        () => EngineEvent.fromJson({'type': 'nope'}),
        throwsFormatException,
      );
    });
  });
}
