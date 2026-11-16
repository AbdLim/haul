import 'dart:async';

import 'package:download_engine/download_engine.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'downloads_cubit.dart';

/// How many one-second samples are kept. The graph shows 60 seconds, plus a
/// couple either side so it can scroll smoothly.
const throughputSamples = 62;

class ThroughputState extends Equatable {
  const ThroughputState({
    required this.samples,
    this.speed = 0,
    this.activeCount = 0,
    this.eta,
    this.lastSampleAt,
  });

  /// A flat line: nothing has been downloading.
  factory ThroughputState.idle() => ThroughputState(
    samples: List<double>.filled(throughputSamples, 0, growable: false),
  );

  /// Bytes per second, once a second, oldest first. The last entry is the
  /// newest.
  final List<double> samples;

  /// Total bytes per second across everything running, as of the last tick.
  final double speed;

  /// How many downloads are running (connecting or transferring).
  final int activeCount;

  /// Combined time left for everything running, or null if unknown.
  final Duration? eta;

  /// When the newest sample was taken, so the graph can scroll between them.
  final DateTime? lastSampleAt;

  /// Nothing is downloading, so there are no numbers worth showing.
  bool get idle => activeCount == 0;

  @override
  List<Object?> get props => [samples, speed, activeCount, eta, lastSampleAt];
}

/// Once a second, records the combined download speed for the header's
/// number and graph. It counts only downloads that are running right now, so
/// a finished or paused download can never leave a stale number behind.
class ThroughputCubit extends Cubit<ThroughputState> {
  ThroughputCubit({
    required LiveCubit live,
    required DownloadsCubit downloads,
    Stream<void>? ticks,
    DateTime Function()? clock,
  }) : _live = live,
       _downloads = downloads,
       _clock = clock ?? DateTime.now,
       super(ThroughputState.idle()) {
    _sub = (ticks ?? Stream<void>.periodic(const Duration(seconds: 1))).listen(
      (_) => sample(),
    );
  }

  final LiveCubit _live;
  final DownloadsCubit _downloads;
  final DateTime Function() _clock;
  late final StreamSubscription<void> _sub;

  /// Takes one sample now. Called by the ticker; public so tests can step it.
  void sample() {
    final running = {
      for (final d in _downloads.state.downloads)
        if (d.snapshot.status == DownloadStatus.probing ||
            d.snapshot.status == DownloadStatus.downloading)
          d.id,
    };

    var speed = 0.0;
    var remaining = 0;
    var knownTotals = false;
    for (final e in _live.state.values) {
      if (!running.contains(e.id)) continue;
      speed += e.bytesPerSecond;
      final total = e.totalBytes;
      if (total != null) {
        knownTotals = true;
        remaining += (total - e.downloadedBytes).clamp(0, total);
      }
    }
    if (running.isEmpty) speed = 0;

    final eta = knownTotals && speed > 0
        ? Duration(seconds: (remaining / speed).ceil())
        : null;

    final next = [...state.samples.skip(1), speed];
    emit(
      ThroughputState(
        samples: List<double>.unmodifiable(next),
        speed: speed,
        activeCount: running.length,
        eta: eta,
        lastSampleAt: _clock(),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
