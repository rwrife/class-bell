/// Praise tally model: whole-class and per-group points toward one shared
/// class goal, scoped to a single session with an explicit per-session
/// reset.
///
/// Privacy contract (blocking): this model has NO per-student score fields.
/// Points attach only to the whole class or to a group label. There is no
/// way to record praise — or anything else — against an individual child,
/// and serialization keys make that auditable.
library;

class PraiseSession {
  PraiseSession({required this.goal, required this.groups, int? sessionNumber})
    : assert(goal > 0, 'goal must be positive'),
      _sessionNumber = sessionNumber ?? 1 {
    _groupPoints = {for (final g in groups) g: 0};
  }

  factory PraiseSession.fromJson(Map<String, dynamic> json) {
    final groups = (json['groupPoints'] as Map<String, dynamic>).keys.toList();
    final session = PraiseSession(
      goal: json['goal'] as int,
      groups: groups,
      sessionNumber: json['sessionNumber'] as int?,
    );
    session._classPoints = json['classPoints'] as int;
    (json['groupPoints'] as Map<String, dynamic>).forEach((k, v) {
      session._groupPoints[k] = v as int;
    });
    return session;
  }

  /// Shared class goal (e.g. 50 points → movie afternoon).
  final int goal;

  /// Group labels that can earn praise this session.
  final List<String> groups;

  int _sessionNumber;
  int _classPoints = 0;
  late Map<String, int> _groupPoints;

  int get sessionNumber => _sessionNumber;

  /// Points awarded directly to the whole class.
  int get classPoints => _classPoints;

  /// Points earned by a specific group (0 for unknown labels).
  int groupPoints(String group) => _groupPoints[group] ?? 0;

  /// Sum of all group points.
  int get totalGroupPoints => _groupPoints.values.fold(0, (sum, p) => sum + p);

  /// Progress toward the shared goal: class points plus all group points.
  int get progress => _classPoints + totalGroupPoints;

  bool get goalReached => progress >= goal;

  /// Award whole-class praise. [points] must be positive — this is a praise
  /// board, not a penalty board; the UI must not offer subtraction.
  void addClassPoints(int points) {
    _checkPoints(points);
    _classPoints += points;
  }

  /// Correction: subtract mistaken whole-class points down to 0 minimum.
  void removeClassPoints(int points) {
    _checkPoints(points);
    _classPoints = (_classPoints - points).clamp(0, 1 << 30);
  }

  /// Award praise to a group declared for this session.
  void addGroupPoints(String group, int points) {
    _checkPoints(points);
    if (!_groupPoints.containsKey(group)) {
      throw ArgumentError.value(group, 'group', 'unknown group for session');
    }
    _groupPoints[group] = _groupPoints[group]! + points;
  }

  /// Correction: subtract mistaken group points down to 0 minimum.
  void removeGroupPoints(String group, int points) {
    _checkPoints(points);
    if (!_groupPoints.containsKey(group)) {
      throw ArgumentError.value(group, 'group', 'unknown group for session');
    }
    _groupPoints[group] = (_groupPoints[group]! - points).clamp(0, 1 << 30);
  }

  /// Per-session reset: clears all tallies and bumps the session counter.
  void resetSession() {
    _classPoints = 0;
    _groupPoints = {for (final g in groups) g: 0};
    _sessionNumber++;
  }

  void _checkPoints(int points) {
    if (points <= 0) {
      throw ArgumentError.value(points, 'points', 'praise points must be > 0');
    }
  }

  Map<String, dynamic> toJson() => {
    'goal': goal,
    'sessionNumber': _sessionNumber,
    'classPoints': _classPoints,
    'groupPoints': Map<String, int>.from(_groupPoints),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PraiseSession &&
          runtimeType == other.runtimeType &&
          goal == other.goal &&
          _sessionNumber == other._sessionNumber &&
          _classPoints == other._classPoints &&
          _mapEquals(_groupPoints, other._groupPoints);

  @override
  int get hashCode => Object.hash(
    goal,
    _sessionNumber,
    _classPoints,
    Object.hashAllUnordered(
      _groupPoints.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  static bool _mapEquals(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
