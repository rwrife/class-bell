import 'package:class_bell/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClock {
  Duration now = Duration.zero;
  Duration read() => now;
  void advance(Duration d) => now += d;
}

void main() {
  group('CountdownTimer', () {
    test('start/pause/resume accumulate monotonic elapsed time', () {
      final clock = _FakeClock();
      final timer = CountdownTimer(clock: clock.read);

      timer.start(const Duration(minutes: 1)); // 60s
      expect(timer.phase, TimerPhase.running);

      clock.advance(const Duration(seconds: 20));
      expect(timer.tick().elapsed, const Duration(seconds: 20));

      timer.pause();
      expect(timer.phase, TimerPhase.paused);

      // Clock keeps running while paused (e.g. device asleep) — must not count.
      clock.advance(const Duration(minutes: 10));
      final snap = timer.tick();
      expect(snap.elapsed, const Duration(seconds: 20));
      expect(snap.remaining, const Duration(seconds: 40));

      timer.resume();
      clock.advance(const Duration(seconds: 30));
      expect(timer.tick().elapsed, const Duration(seconds: 50));
    });

    test('sleep/background/resume loses no time beyond bounded tolerance', () {
      final clock = _FakeClock();
      final timer = CountdownTimer(clock: clock.read);

      timer.start(const Duration(minutes: 5)); // 300s
      clock.advance(const Duration(seconds: 60));
      timer.pause();

      // App backgrounded for 2 hours of wall-clock time
      clock.advance(const Duration(hours: 2));
      timer.resume();

      // Only 1 minute was actually running before pause; nothing gained.
      var snap = timer.tick();
      expect(snap.elapsed, const Duration(seconds: 60));

      // Run out the rest: 240s remaining
      clock.advance(const Duration(seconds: 240));
      snap = timer.tick();
      expect(snap.phase, TimerPhase.finished);
      // Drift is exactly zero: elapsed == duration
      expect(snap.elapsed, const Duration(seconds: 300));
      expect(snap.remaining, Duration.zero);
    });

    test('end event fires exactly once', () {
      final clock = _FakeClock();
      final timer = CountdownTimer(clock: clock.read);

      timer.start(const Duration(seconds: 10));
      expect(timer.endEventPending, isFalse);

      clock.advance(const Duration(seconds: 10));
      final snap = timer.tick();
      expect(snap.phase, TimerPhase.finished);
      expect(timer.endEventPending, isTrue);

      // Repeated ticks in finished phase do not re-arm the event.
      clock.advance(const Duration(minutes: 5));
      timer.tick();
      timer.tick();

      expect(timer.consumeEndEvent(), isTrue);
      expect(timer.consumeEndEvent(), isFalse);
      expect(timer.endEventPending, isFalse);
    });

    test('skip jumps to end and fires end event once', () {
      final clock = _FakeClock();
      final timer = CountdownTimer(clock: clock.read);

      timer.start(const Duration(minutes: 3));
      clock.advance(const Duration(seconds: 30));
      timer.skip();

      expect(timer.phase, TimerPhase.finished);
      expect(timer.tick().elapsed, const Duration(minutes: 3));
      expect(timer.consumeEndEvent(), isTrue);
      expect(timer.consumeEndEvent(), isFalse);
    });

    test('skip while paused also finishes the run', () {
      final clock = _FakeClock();
      final timer = CountdownTimer(clock: clock.read);

      timer.start(const Duration(minutes: 2));
      timer.pause();
      timer.skip();
      expect(timer.phase, TimerPhase.finished);
      expect(timer.consumeEndEvent(), isTrue);
    });

    test('reset returns to idle without firing event', () {
      final clock = _FakeClock();
      final timer = CountdownTimer(clock: clock.read);

      timer.start(const Duration(seconds: 5));
      clock.advance(const Duration(seconds: 2));
      timer.reset();

      expect(timer.phase, TimerPhase.idle);
      expect(timer.endEventPending, isFalse);
      expect(timer.tick().elapsed, Duration.zero);
    });

    test('running past end while UI was not ticking finishes on next tick', () {
      final clock = _FakeClock();
      final timer = CountdownTimer(clock: clock.read);

      timer.start(const Duration(seconds: 10));
      // No ticks for a long time (frozen UI / backgrounded app)
      clock.advance(const Duration(minutes: 30));

      final snap = timer.tick();
      expect(snap.phase, TimerPhase.finished);
      expect(snap.remaining, Duration.zero);
      expect(timer.consumeEndEvent(), isTrue);
    });

    test('start rejects non-positive duration', () {
      final clock = _FakeClock();
      final timer = CountdownTimer(clock: clock.read);
      expect(() => timer.start(Duration.zero), throwsArgumentError);
      expect(
        () => timer.start(const Duration(seconds: -1)),
        throwsArgumentError,
      );
    });

    test('progress is clamped 0..1 for ring rendering', () {
      final clock = _FakeClock();
      final timer = CountdownTimer(clock: clock.read);

      timer.start(const Duration(seconds: 4));
      expect(timer.tick().progress, 0.0);
      clock.advance(const Duration(seconds: 1));
      expect(timer.tick().progress, closeTo(0.25, 1e-9));
      clock.advance(const Duration(seconds: 10));
      expect(timer.tick().progress, 1.0);
    });
  });
}
