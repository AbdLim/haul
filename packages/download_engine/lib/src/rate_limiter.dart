import 'dart:async';

/// One token bucket shared by every worker of every download.
///
/// The bucket holds at most one second of the limit and refills
/// continuously. Callers [acquire] before writing a chunk and wait if the
/// bucket is in debt, which also pauses their response stream. A limit of
/// zero means unlimited, and it can change at any time.
class RateLimiter {
  RateLimiter({
    int bytesPerSecond = 0,
    Duration Function()? clock,
    Future<void> Function(Duration)? sleep,
  }) : _limit = bytesPerSecond,
       _clock = clock ?? _stopwatchClock(),
       _sleep = sleep ?? ((d) => Future<void>.delayed(d)) {
    _lastRefill = _clock();
  }

  static Duration Function() _stopwatchClock() {
    final sw = Stopwatch()..start();
    return () => sw.elapsed;
  }

  final Duration Function() _clock;
  final Future<void> Function(Duration) _sleep;
  int _limit;
  double _tokens = 0;
  late Duration _lastRefill;
  var _changed = Completer<void>();

  /// Bytes per second; 0 is unlimited.
  int get bytesPerSecond => _limit;

  set bytesPerSecond(int value) {
    final v = value < 0 ? 0 : value;
    if (v == _limit) return;
    _refill();
    _limit = v;
    if (_tokens > v) _tokens = v.toDouble();
    // Wake everyone who is waiting so they see the new rate.
    final old = _changed;
    _changed = Completer<void>();
    old.complete();
  }

  /// Takes [bytes] from the bucket, waiting if that leaves it in debt.
  Future<void> acquire(int bytes) async {
    if (_limit == 0 || bytes <= 0) return;
    _refill();
    _tokens -= bytes;
    if (_tokens >= 0) return;
    final wait = Duration(
      microseconds: (-_tokens * Duration.microsecondsPerSecond / _limit).ceil(),
    );
    await Future.any([_sleep(wait), _changed.future]);
  }

  void _refill() {
    final now = _clock();
    final elapsed = now - _lastRefill;
    _lastRefill = now;
    if (_limit == 0) {
      _tokens = 0;
      return;
    }
    _tokens += elapsed.inMicroseconds * _limit / Duration.microsecondsPerSecond;
    // Never hold more than one second's worth.
    if (_tokens > _limit) _tokens = _limit.toDouble();
  }
}
