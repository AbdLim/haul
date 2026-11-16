import 'dart:math';

import 'package:download_engine/download_engine.dart';

/// One segment as a block in the map: where it sits across the file and how
/// much of it has been fetched.
class BlockRect {
  const BlockRect({
    required this.id,
    required this.left,
    required this.right,
    required this.fill,
    required this.done,
  });

  final int id;
  final double left;
  final double right;

  /// 0 to 1: the share of this segment already downloaded.
  final double fill;
  final bool done;

  double get width => right - left;

  BlockRect copyWith({double? left, double? right, double? fill}) => BlockRect(
    id: id,
    left: left ?? this.left,
    right: right ?? this.right,
    fill: fill ?? this.fill,
    done: done,
  );
}

/// Where each segment goes in a map [width] wide. The whole file runs from
/// left to right, so a segment's block is as wide as its share of the file.
List<BlockRect> layoutBlocks(List<Segment> segments, double width) {
  if (segments.isEmpty || width <= 0) return const [];
  var total = 0;
  for (final s in segments) {
    total = max(total, s.end + 1);
  }
  if (total <= 0) return const [];
  final sorted = [...segments]..sort((a, b) => a.start.compareTo(b.start));
  return [
    for (final s in sorted)
      BlockRect(
        id: s.id,
        left: s.start / total * width,
        right: (s.end + 1) / total * width,
        fill: s.length <= 0 ? 1 : (s.downloaded / s.length).clamp(0.0, 1.0),
        done: s.isComplete,
      ),
  ];
}

/// The blocks part-way between two layouts, [t] from 0 to 1.
///
/// A block that was there before moves and resizes to its new place. A block
/// that is new, which happens when a segment is split, grows out of the right
/// end of its final spot while the segment it was cut from shrinks, so the
/// block seems to divide in two.
List<BlockRect> lerpBlocks(List<BlockRect> from, List<BlockRect> to, double t) {
  final before = {for (final b in from) b.id: b};
  double lerp(double a, double b) => a + (b - a) * t;
  return [
    for (final b in to)
      if (before[b.id] case final old?)
        b.copyWith(
          left: lerp(old.left, b.left),
          right: lerp(old.right, b.right),
          fill: lerp(old.fill, b.fill),
        )
      else
        b.copyWith(left: lerp(b.right, b.left)),
  ];
}

/// Whether going from [from] to [to] added a block (a split happened).
bool gainedBlock(List<BlockRect> from, List<BlockRect> to) {
  final ids = {for (final b in from) b.id};
  return to.any((b) => !ids.contains(b.id));
}

/// Speed of each connection, worked out from how its segment's byte count
/// changes between progress events and smoothed so the readout does not jump.
class ConnectionSpeeds {
  final _bytes = <int, int>{};
  final _speed = <int, double>{};
  DateTime? _at;

  /// Feed one progress event's segments, taken at [now].
  void update(List<Segment> segments, DateTime now) {
    final last = _at;
    final seconds = last == null
        ? 0.0
        : now.difference(last).inMicroseconds / 1e6;
    final seen = <int>{};
    for (final s in segments) {
      seen.add(s.id);
      final previous = _bytes[s.id];
      if (previous != null && seconds > 0) {
        final instant = s.downloaded >= previous
            ? (s.downloaded - previous) / seconds
            : 0.0; // started over
        final old = _speed[s.id];
        _speed[s.id] = old == null ? instant : old * 0.5 + instant * 0.5;
      }
      // With no earlier reading there is no speed yet; it reads as zero until
      // the next event gives a real measurement, which is then used as is.
      _bytes[s.id] = s.downloaded;
    }
    _bytes.removeWhere((id, _) => !seen.contains(id));
    _speed.removeWhere((id, _) => !seen.contains(id));
    _at = now;
  }

  /// Bytes per second for a segment's connection, zero if unknown or done.
  double speedOf(int id) => _speed[id] ?? 0;

  void clear() {
    _bytes.clear();
    _speed.clear();
    _at = null;
  }
}
