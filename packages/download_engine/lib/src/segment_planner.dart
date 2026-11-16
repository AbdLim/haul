import 'dart:math';

import 'models/segment.dart';

const _mib = 1024 * 1024;

/// Smallest segment worth its own connection.
const minSegmentBytes = _mib;

/// A segment needs more than this left before another worker may take half.
const minSplitRemainingBytes = 2 * _mib;

/// Cuts a file of [size] bytes into equal segments, one per connection.
///
/// The count is `floor(size / 1 MiB)` clamped to `1..maxConnections`; the
/// last segment takes the remainder. An empty file has no segments.
List<Segment> planSegments(int size, int maxConnections) {
  if (size <= 0) return const [];
  final count = max(1, min(maxConnections, size ~/ minSegmentBytes));
  final base = size ~/ count;
  final segments = <Segment>[];
  var cursor = 0;
  for (var i = 0; i < count; i++) {
    final end = i == count - 1 ? size - 1 : cursor + base - 1;
    segments.add(Segment(id: i, start: cursor, end: end));
    cursor = end + 1;
  }
  return segments;
}

/// The outcome of splitting a segment.
class SplitResult {
  const SplitResult(this.segments, this.created);

  /// The full updated list, with the original shortened and [created] added.
  final List<Segment> segments;

  /// The new tail segment, already marked `active` for the free worker.
  final Segment created;
}

/// Finds the active segment with the most bytes left and, if it has more
/// than 2 MiB remaining, hands the second half of what is left to a new
/// segment. Returns null when nothing is worth splitting.
SplitResult? splitLargest(List<Segment> segments) {
  Segment? victim;
  for (final s in segments) {
    if (s.status != SegmentStatus.active) continue;
    if (s.remaining <= minSplitRemainingBytes) continue;
    if (victim == null || s.remaining > victim.remaining) victim = s;
  }
  if (victim == null) return null;

  final mid = victim.nextByte + victim.remaining ~/ 2;
  final nextId = segments.map((s) => s.id).reduce(max) + 1;
  final created = Segment(
    id: nextId,
    start: mid,
    end: victim.end,
    status: SegmentStatus.active,
  );
  final updated = [
    for (final s in segments)
      if (s.id == victim.id) s.copyWith(end: mid - 1) else s,
    created,
  ];
  return SplitResult(updated, created);
}
