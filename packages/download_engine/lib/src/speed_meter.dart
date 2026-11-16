import 'dart:collection';

/// Rolling-average transfer speed over a fixed window (5 seconds by default).
class SpeedMeter {
  SpeedMeter({
    this.window = const Duration(seconds: 5),
    Duration Function()? clock,
  }) : _clock = clock ?? _stopwatchClock();

  final Duration window;
  final Duration Function() _clock;
  final _samples = Queue<(Duration, int)>();
  Duration? _started;
  int _inWindow = 0;

  static Duration Function() _stopwatchClock() {
    final sw = Stopwatch()..start();
    return () => sw.elapsed;
  }

  /// Records that [bytes] arrived just now.
  void add(int bytes) {
    final now = _clock();
    _started ??= now;
    _samples.add((now, bytes));
    _inWindow += bytes;
    _evict(now);
  }

  /// Bytes per second over the window. Zero until something has arrived,
  /// and zero again once the window has passed with no data.
  double get bytesPerSecond {
    final started = _started;
    if (started == null) return 0;
    final now = _clock();
    _evict(now);
    if (_inWindow == 0) return 0;
    // Until a full window has elapsed, divide by the time actually spent
    // (at least a second, so the first burst doesn't read as a huge spike).
    final elapsed = now - started;
    final span = elapsed < window ? elapsed : window;
    final seconds =
        (span < const Duration(seconds: 1) ? const Duration(seconds: 1) : span)
            .inMicroseconds /
        Duration.microsecondsPerSecond;
    return _inWindow / seconds;
  }

  /// Time to move [remainingBytes] at the current speed, or null when the
  /// speed is zero.
  Duration? eta(int remainingBytes) {
    final speed = bytesPerSecond;
    if (speed <= 0) return null;
    return Duration(seconds: (remainingBytes / speed).ceil());
  }

  void reset() {
    _samples.clear();
    _inWindow = 0;
    _started = null;
  }

  void _evict(Duration now) {
    while (_samples.isNotEmpty && now - _samples.first.$1 > window) {
      _inWindow -= _samples.removeFirst().$2;
    }
  }
}
