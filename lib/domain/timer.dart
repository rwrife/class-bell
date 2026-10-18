/// Monotonic-clock based countdown timer state machine (pure Dart).
///
/// Elapsed time is always derived from a monotonic clock source, never from
/// accumulating per-tick deltas, so process sleep / backgrounding cannot
/// lose or gain minutes: on resume the wall-clock-monotonic delta is simply
/// observed. The end event fires exactly once per run.
library;

/// Monotonic time source (injectable for deterministic tests).
typedef MonotonicClock = Duration Function();

enum TimerPhase { idle, running, paused, finished }

/// Immutable snapshot of a timer for UI rendering.
class TimerSnapshot {
  const TimerSnapshot({
    required this.phase,
    required this.duration,
    required this.elapsed,
  });

  final TimerPhase phase;
  final Duration duration;
  final Duration elapsed;

  Duration get remaining {
    final r = duration - elapsed;
    return r.isNegative ? Duration.zero : r;
  }

  /// Fraction of the timer elapsed, clamped to 0..1, for countdown rings.
  double get progress {
    if (duration <= Duration.zero) return 1.0;
    final p = elapsed.inMicroseconds / duration.inMicroseconds;
    return p.clamp(0.0, 1.0);
  }
}

class CountdownTimer {
  CountdownTimer({required this._clock});

  final MonotonicClock _clock;

  TimerPhase _phase = TimerPhase.idle;
  Duration _duration = Duration.zero;
  Duration _accumulated = Duration.zero;
  Duration? _segmentStart;
  bool _endEventPending = false;

  TimerPhase get phase => _phase;
  Duration get duration => _duration;

  /// True while an unacknowledged end event is waiting (drives the chime).
  bool get endEventPending => _endEventPending;

  /// Acknowledge the end event (play chime once). Returns true exactly once
  /// per completed run.
  bool consumeEndEvent() {
    if (!_endEventPending) return false;
    _endEventPending = false;
    return true;
  }

  void start(Duration duration) {
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'must be positive');
    }
    _duration = duration;
    _accumulated = Duration.zero;
    _segmentStart = _clock();
    _endEventPending = false;
    _phase = TimerPhase.running;
    // A zero-length-at-start timer cannot happen (duration > 0), but a
    // clock with huge granularity could already be past the end:
    _checkFinished();
  }

  void pause() {
    if (_phase != TimerPhase.running) return;
    _accumulated += _clock() - _segmentStart!;
    _segmentStart = null;
    _phase = TimerPhase.paused;
  }

  void resume() {
    if (_phase != TimerPhase.paused) return;
    _segmentStart = _clock();
    _phase = TimerPhase.running;
    _checkFinished();
  }

  /// Jump straight to the end of the current run (fires the end event).
  void skip() {
    if (_phase != TimerPhase.running && _phase != TimerPhase.paused) return;
    _finish();
  }

  /// Return to the idle state without firing any event.
  void reset() {
    _phase = TimerPhase.idle;
    _accumulated = Duration.zero;
    _segmentStart = null;
    _endEventPending = false;
  }

  /// Current snapshot; also advances a running timer that has passed its
  /// end instant into the finished phase (end event fires once).
  TimerSnapshot tick() {
    if (_phase == TimerPhase.running) {
      _checkFinished();
    }
    return TimerSnapshot(
      phase: _phase,
      duration: _duration,
      elapsed: _rawElapsed(),
    );
  }

  Duration _rawElapsed() {
    switch (_phase) {
      case TimerPhase.idle:
        return Duration.zero;
      case TimerPhase.running:
        return _accumulated + (_clock() - _segmentStart!);
      case TimerPhase.paused:
        return _accumulated;
      case TimerPhase.finished:
        return _duration;
    }
  }

  void _checkFinished() {
    if (_phase == TimerPhase.running && _rawElapsed() >= _duration) {
      _finish();
    }
  }

  void _finish() {
    _accumulated = _duration;
    _segmentStart = null;
    _phase = TimerPhase.finished;
    if (!_endEventPending) {
      _endEventPending = true;
    }
  }
}
