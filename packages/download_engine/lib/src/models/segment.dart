enum SegmentStatus { pending, active, done }

/// A contiguous byte range of the file. [start] and [end] are inclusive,
/// like HTTP `Range`.
class Segment {
  const Segment({
    required this.id,
    required this.start,
    required this.end,
    this.downloaded = 0,
    this.status = SegmentStatus.pending,
  });

  final int id;
  final int start;
  final int end;
  final int downloaded;
  final SegmentStatus status;

  int get length => end - start + 1;
  int get remaining => length - downloaded;

  /// First byte that still has to be fetched.
  int get nextByte => start + downloaded;
  bool get isComplete => downloaded >= length;

  Segment copyWith({int? end, int? downloaded, SegmentStatus? status}) =>
      Segment(
        id: id,
        start: start,
        end: end ?? this.end,
        downloaded: downloaded ?? this.downloaded,
        status: status ?? this.status,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'start': start,
    'end': end,
    'downloaded': downloaded,
    'status': status.name,
  };

  factory Segment.fromJson(Map<String, Object?> json) => Segment(
    id: json['id']! as int,
    start: json['start']! as int,
    end: json['end']! as int,
    downloaded: json['downloaded']! as int,
    status: SegmentStatus.values.byName(json['status']! as String),
  );

  @override
  String toString() =>
      'Segment($id: $start-$end, $downloaded done, ${status.name})';
}
