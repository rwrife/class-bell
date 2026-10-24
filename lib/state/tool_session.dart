import 'dart:async' as async show Timer;
import 'dart:async' show unawaited;
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import '../domain/fair_draw_bag.dart';
import '../domain/praise.dart';

import '../domain/timer.dart';
import '../repository/bell_repository.dart';
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

/// Live classroom session for the four tools plus projector mode.
///
/// Settings, praise tallies, and aggregate day history flow through the
/// optional [BellRepository]; the timer itself is never persisted, so a
/// restart always returns to a clean idle countdown (no phantom minutes).
/// It owns the monotonic clock, the draw bag, the praise session, the
/// bundled audio cue, and the teacher lock.
class ToolSession extends ChangeNotifier with WidgetsBindingObserver {
  ToolSession(
    this.store, {
    MonotonicClock? clock,
    this.now,
    this.repository,
    this._player,
  }) : _stopwatch = Stopwatch()..start() {
    _clock = clock ?? () => _stopwatch.elapsed;
    timer = CountdownTimer(clock: _clock);
    final repo = repository ?? store.repository;
    if (repo != null) {
      final snap = repo.load();
      presetMinutes = snap.presetMinutes;
      goal = snap.goal;
      quietSound = snap.quietSound;
      unlockComboIndex = snap.unlockComboIndex.clamp(
        0,
        unlockCombos.length - 1,
      );
    }
    store.addListener(_rosterChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  static const Duration lockLongPress = Duration(milliseconds: 900);

  final RosterStore store;
  final BellRepository? repository;
  final DateTime Function()? now;
  DateTime _currentNow() => (now ?? DateTime.now)();

  final Stopwatch _stopwatch;
  AudioPlayer? _player;
  late final MonotonicClock _clock;
  late final CountdownTimer timer;
  // Whole seconds of the current run already written to history. Only
  // elapsed time that actually passed while running is ever recorded, so a
  // killed process can lose at most the last partial second (never gain time).
  int _recordedSeconds = 0;

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

  BellRepository? get _repo => repository ?? store.repository;

  PraiseSession get praise {
    final roster = store.selectedRoster;
    if (_praise == null || _praiseRosterId != roster?.id) {
      _praiseRosterId = roster?.id;
      final groups = roster?.groups ?? const <String>[];
      final saved = roster == null
          ? null
          : _repo?.load().praiseByRoster[roster.id];
      if (saved != null) {
        final points = (saved['groupPoints'] as Map<String, dynamic>? ?? {});
        _praise = PraiseSession.fromJson({
          'goal': goal,
          'sessionNumber': saved['sessionNumber'],
          'classPoints': saved['classPoints'] ?? 0,
          'groupPoints': {for (final g in groups) g: points[g] ?? 0},
        });
      } else {
        _praise = PraiseSession(goal: goal, groups: groups);
      }
    }
    return _praise!;
  }

  void _saveSettings() {
    final repo = _repo;
    if (repo == null) return;
    repo.save(
      repo.load().copyWith(
        presetMinutes: presetMinutes,
        goal: goal,
        quietSound: quietSound,
        unlockComboIndex: unlockComboIndex,
      ),
    );
  }

  void _savePraise() {
    final repo = _repo;
    final id = _praiseRosterId;
    if (repo == null || id == null) return;
    final snap = repo.load();
    repo.save(
      snap.copyWith(
        praiseByRoster: {...snap.praiseByRoster, id: praise.toJson()},
      ),
    );
  }

  /// Write newly elapsed whole seconds of the current timer run to history.
  void _flushFocus() {
    final repo = _repo;
    if (repo == null) return;
    final elapsed = timer.tick().elapsed.inSeconds;
    final delta = elapsed - _recordedSeconds;
    if (delta > 0) {
      repo.recordFocus(_currentNow(), delta);
      _recordedSeconds = elapsed;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _flushFocus();
    refresh();
  }

  void _rosterChanged() {
    // The bag is intentionally kept so the next draw can report an explicit
    // reshuffle instead of silently changing rotation.
    if (_praiseRosterId != store.selectedRoster?.id) _praise = null;
    notifyListeners();
  }

  /// Advance a running timer; fires the bundled chime exactly once per run.
  void refresh() {
    final before = timer.phase;
    timer.tick();
    if (timer.phase == TimerPhase.running || before != timer.phase) {
      _flushFocus();
    }
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
        _flushFocus(); // settle the previous run's tail before restarting
        _recordedSeconds = 0;
        timer.start(Duration(minutes: presetMinutes));
      case TimerPhase.running:
        _flushFocus(); // settle whole seconds before the clock stops
        timer.pause();
      case TimerPhase.paused:
        timer.resume();
    }
    _syncTicker();
    refresh();
    notifyListeners();
  }

  void skip() {
    _flushFocus(); // count what actually ran, not the nominal preset
    timer.skip();
    _recordedSeconds = timer.duration.inSeconds; // skip is not focus time
    _syncTicker();
    refresh();
    notifyListeners();
  }

  void setPreset(int minutes) {
    if (locked || minutes < 1 || minutes > 120) return;
    presetMinutes = minutes;
    _flushFocus();
    timer.reset();
    _recordedSeconds = 0;
    _syncTicker();
    _saveSettings();
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
    final before = praise.progress;
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
    final delta = praise.progress - before;
    if (delta != 0) {
      // Praise corrections are part of the same aggregate day tally.
      _repo?.recordPraise(_currentNow(), delta);
      _savePraise();
    }
    notifyListeners();
  }

  void resetPraise() {
    if (locked) return;
    praise.resetSession();
    _savePraise();
    notifyListeners();
  }

  void setGoal(int value) {
    if (locked || value < 1 || value > 9999) return;
    goal = value;
    _praise = PraiseSession(
      goal: goal,
      groups: store.selectedRoster?.groups ?? const [],
    );
    _saveSettings();
    _savePraise();
    notifyListeners();
  }

  void toggleQuietSound() {
    if (locked) return;
    quietSound = !quietSound;
    _saveSettings();
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
    _saveSettings();
    notifyListeners();
  }

  /// Flush live timer time before a backup. Restores and wipes never resurrect
  /// the active timer; elapsed time before the operation remains in history.
  void flushForBackup() => _flushFocus();

  void resetAfterDataChange() {
    _tickTimer?.cancel();
    _tickTimer = null;
    timer.reset();
    _recordedSeconds = 0;
    _praise = null;
    _praiseRosterId = null;
    _bag = null;
    _bagRosterId = null;
    selectedName = null;
    remainingDraws = 0;
    drawNotice = '';
    dim = false;
    quietSound = false;
    presetMinutes = 5;
    goal = 20;
    unlockComboIndex = 0;
    final snap = _repo?.load();
    if (snap != null) {
      quietSound = snap.quietSound;
      presetMinutes = snap.presetMinutes;
      goal = snap.goal;
      unlockComboIndex = snap.unlockComboIndex.clamp(
        0,
        unlockCombos.length - 1,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _flushFocus(); // settle the current run's whole seconds
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(_rosterChanged);
    _tickTimer?.cancel();
    final player = _player;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }
}
