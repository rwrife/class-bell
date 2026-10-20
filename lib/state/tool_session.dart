import 'dart:async' as async show Timer;
import 'dart:async' show unawaited;
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import '../domain/fair_draw_bag.dart';
import '../domain/praise.dart';

import '../domain/timer.dart';
import 'roster_store.dart';

// ponytail: one bundled cue for both timer end and quiet signal; split into a
// sound pack when classroom sound themes exist.
const String _cueAsset = 'audio/chime.wav';

/// Teacher-lock unlock combinations the settings screen can cycle through.
class UnlockCombo {
  const UnlockCombo(this.label, this.keyName);

  final String label;
  final String keyName;
}

const List<UnlockCombo> unlockCombos = [
  UnlockCombo('Ctrl+Alt+L', 'KeyL'),
  UnlockCombo('Ctrl+Shift+K', 'KeyK'),
  UnlockCombo('Ctrl+Alt+F9', 'F9'),
];

/// Ephemeral classroom session for the four tools plus projector mode.
///
/// Persistence and session history belong to issue #5; this object only holds
/// live state. It owns the monotonic clock, the draw bag, the praise session,
/// the bundled audio cue, and the teacher lock.
class ToolSession extends ChangeNotifier with WidgetsBindingObserver {
  ToolSession(this.store, {MonotonicClock? clock, this._player})
    : _stopwatch = Stopwatch()..start() {
    _clock = clock ?? () => _stopwatch.elapsed;
    timer = CountdownTimer(clock: _clock);
    store.addListener(_rosterChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  static const Duration lockLongPress = Duration(milliseconds: 900);

  final RosterStore store;
  final Stopwatch _stopwatch;
  AudioPlayer? _player;
  late final MonotonicClock _clock;
  late final CountdownTimer timer;

  FairDrawBag? _bag;
  String? _bagRosterId;
  async.Timer? _tickTimer;
  PraiseSession? _praise;
  String? _praiseRosterId;

  String? selectedName;
  String drawNotice = '';
  int remainingDraws = 0;
  bool dim = false;
  bool quietSound = false;
  int presetMinutes = 5;
  int goal = 20;
  bool locked = false;
  bool projector = false;
  int unlockComboIndex = 0;
  String? audioError;

  UnlockCombo get unlockCombo => unlockCombos[unlockComboIndex];

  TimerSnapshot get snapshot => timer.tick();

  PraiseSession get praise {
    final roster = store.selectedRoster;
    if (_praise == null || _praiseRosterId != roster?.id) {
      _praiseRosterId = roster?.id;
      _praise = PraiseSession(goal: goal, groups: roster?.groups ?? const []);
    }
    return _praise!;
  }

  void _rosterChanged() {
    // The bag is intentionally kept so the next draw can report an explicit
    // reshuffle instead of silently changing rotation.
    if (_praiseRosterId != store.selectedRoster?.id) _praise = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => refresh();

  /// Advance a running timer; fires the bundled chime exactly once per run.
  void refresh() {
    final before = timer.phase;
    timer.tick();
    if (timer.consumeEndEvent()) unawaited(_play());
    if (before != timer.phase) _syncTicker();
    if (timer.phase == TimerPhase.running || before != timer.phase) {
      notifyListeners();
    }
  }

  /// Ticking is bounded: only while running, so idle screens stay quiet and
  /// widget tests can settle.
  void _syncTicker() {
    final shouldTick = timer.phase == TimerPhase.running;
    if (shouldTick && _tickTimer == null) {
      _tickTimer = async.Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => refresh(),
      );
    } else if (!shouldTick) {
      _tickTimer?.cancel();
      _tickTimer = null;
    }
  }

  Future<void> _play() async {
    try {
      await (_player ??= AudioPlayer()).play(
        AssetSource(_cueAsset),
        volume: 0.35,
      );
    } catch (error) {
      // Offline classroom tools must degrade silently but visibly.
      audioError = 'Sound unavailable: $error';
      notifyListeners();
    }
  }

  void toggleTimer() {
    switch (timer.phase) {
      case TimerPhase.idle:
      case TimerPhase.finished:
        timer.start(Duration(minutes: presetMinutes));
      case TimerPhase.running:
        timer.pause();
      case TimerPhase.paused:
        timer.resume();
    }
    _syncTicker();
    refresh();
    notifyListeners();
  }

  void skip() {
    timer.skip();
    _syncTicker();
    refresh();
    notifyListeners();
  }

  void setPreset(int minutes) {
    if (locked || minutes < 1 || minutes > 120) return;
    presetMinutes = minutes;
    timer.reset();
    _syncTicker();
    notifyListeners();
  }

  void toggleDim() {
    dim = !dim;
    notifyListeners();
  }

  void draw() {
    final roster = store.selectedRoster;
    if (roster == null) {
      selectedName = null;
      remainingDraws = 0;
      drawNotice = 'Create a class first';
      notifyListeners();
      return;
    }
    if (_bag == null || _bagRosterId != roster.id) {
      _bag = FairDrawBag(seed: Random().nextInt(1 << 32), roster: roster);
      _bagRosterId = roster.id;
    }
    final outcome = _bag!.draw(roster);
    selectedName = outcome.student?.displayName;
    remainingDraws = outcome.remainingInBag;
    drawNotice = switch (outcome.status) {
      BagStatus.rebuilt =>
        'Rotation rebuilt after a class change or completion',
      BagStatus.empty =>
        'No eligible names — add names or continue the rotation',
      BagStatus.drawn =>
        remainingDraws == 0
            ? 'Rotation complete — everyone had a turn'
            : '$remainingDraws left before anyone repeats',
    };
    notifyListeners();
  }

  void toggleExclusion(String studentId) {
    final roster = store.selectedRoster;
    if (roster == null) return;
    store.toggleStudentExclusion(rosterId: roster.id, studentId: studentId);
  }

  void praisePoint(String? group, {bool subtract = false}) {
    if (group == null) {
      if (subtract) {
        praise.removeClassPoints(1);
      } else {
        praise.addClassPoints(1);
      }
    } else if (subtract) {
      praise.removeGroupPoints(group, 1);
    } else {
      praise.addGroupPoints(group, 1);
    }
    notifyListeners();
  }

  void resetPraise() {
    if (locked) return;
    praise.resetSession();
    notifyListeners();
  }

  void setGoal(int value) {
    if (locked || value < 1 || value > 9999) return;
    goal = value;
    _praise = PraiseSession(
      goal: goal,
      groups: store.selectedRoster?.groups ?? const [],
    );
    notifyListeners();
  }

  void toggleQuietSound() {
    if (locked) return;
    quietSound = !quietSound;
    notifyListeners();
  }

  void quietCue() {
    if (quietSound) unawaited(_play());
  }

  void enterProjector() {
    projector = true;
    locked = true;
    notifyListeners();
  }

  void unlock() {
    if (!locked) return;
    locked = false;
    notifyListeners();
  }

  void leaveProjector() {
    if (locked) return;
    projector = false;
    notifyListeners();
  }

  void cycleUnlockCombo() {
    if (locked) return;
    unlockComboIndex = (unlockComboIndex + 1) % unlockCombos.length;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(_rosterChanged);
    _tickTimer?.cancel();
    final player = _player;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }
}
