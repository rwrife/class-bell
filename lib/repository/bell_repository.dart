import '../domain/roster.dart';

/// Only aggregate classroom data crosses the history boundary. No student IDs.
class DaySummary {
  const DaySummary(this.day, this.praisePoints, this.focusSeconds);

  final String day;
  final int praisePoints;
  final int focusSeconds;
  int get focusMinutes => focusSeconds ~/ 60;
  Map<String, dynamic> toJson() => {
    'day': day,
    'praisePoints': praisePoints,
    'focusSeconds': focusSeconds,
  };
}

class BellSnapshot {
  const BellSnapshot({
    this.rosters = const [],
    this.selectedRosterId = '',
    this.presetMinutes = 5,
    this.goal = 20,
    this.quietSound = false,
    this.unlockComboIndex = 0,
    this.praiseByRoster = const {},
  });

  final List<Roster> rosters;
  final String selectedRosterId;
  final int presetMinutes;
  final int goal;
  final bool quietSound;
  final int unlockComboIndex;
  final Map<String, Map<String, dynamic>> praiseByRoster;

  BellSnapshot copyWith({
    List<Roster>? rosters,
    String? selectedRosterId,
    int? presetMinutes,
    int? goal,
    bool? quietSound,
    int? unlockComboIndex,
    Map<String, Map<String, dynamic>>? praiseByRoster,
  }) => BellSnapshot(
    rosters: rosters ?? this.rosters,
    selectedRosterId: selectedRosterId ?? this.selectedRosterId,
    presetMinutes: presetMinutes ?? this.presetMinutes,
    goal: goal ?? this.goal,
    quietSound: quietSound ?? this.quietSound,
    unlockComboIndex: unlockComboIndex ?? this.unlockComboIndex,
    praiseByRoster: praiseByRoster ?? this.praiseByRoster,
  );
}

abstract interface class BellRepository {
  BellSnapshot load();
  void save(BellSnapshot snapshot);
  void recordFocus(DateTime when, int seconds);
  void recordPraise(DateTime when, int delta);
  List<DaySummary> history();
  void clearAll();
  void restore(BellSnapshot snapshot, List<DaySummary> history);
  void close();
}
