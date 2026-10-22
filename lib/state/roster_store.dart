import 'package:flutter/foundation.dart';

import '../domain/roster.dart';
import '../repository/bell_repository.dart';

/// In-memory roster store with validation and change notification.
///
/// Privacy guarantees:
/// - Display name (first name/alias) only; no last names, emails, photos.
/// - Initials and group tag are optional.
/// - Validation rejects empty/overlong names and email-like text.
///   Multi-word aliases remain allowed; teachers should enter aliases only.
/// - Rosters persist locally when a repository is provided.
class RosterStore extends ChangeNotifier {
  RosterStore({
    List<Roster>? initialRosters,
    String? selectedRosterId,
    this.repository,
  }) {
    final snapshot = repository?.load() ?? const BellSnapshot();
    _rosters = List<Roster>.from(initialRosters ?? snapshot.rosters);
    _selectedRosterId =
        selectedRosterId ??
        (repository != null
            ? snapshot.selectedRosterId
            : (_rosters.isEmpty ? '' : _rosters.first.id));
    if (_rosters.isNotEmpty &&
        !_rosters.any((r) => r.id == _selectedRosterId)) {
      _selectedRosterId = _rosters.first.id;
    }
  }

  final BellRepository? repository;
  late final List<Roster> _rosters;
  late String _selectedRosterId;

  @override
  void notifyListeners() {
    final db = repository;
    if (db != null) {
      db.save(
        db.load().copyWith(
          rosters: _rosters,
          selectedRosterId: _selectedRosterId,
        ),
      );
    }
    super.notifyListeners();
  }

  int _idCounter = 0;

  String _nextId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  List<Roster> get rosters => List.unmodifiable(_rosters);

  String get selectedRosterId => _selectedRosterId;

  Roster? get selectedRoster {
    for (final r in _rosters) {
      if (r.id == _selectedRosterId) return r;
    }
    return _rosters.isNotEmpty ? _rosters.first : null;
  }

  void selectRoster(String id) {
    if (_selectedRosterId != id) {
      _selectedRosterId = id;
      notifyListeners();
    }
  }

  static String? validateRosterName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Class name cannot be empty';
    }
    if (name.trim().length > 40) {
      return 'Class name is too long (max 40 characters)';
    }
    return null;
  }

  static String? validateStudentDisplayName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'First name or alias is required';
    }
    final trimmed = name.trim();
    if (trimmed.length > 25) {
      return 'Name is too long (max 25 characters)';
    }
    if (trimmed.contains('@')) {
      return 'Emails not allowed. First name or alias only.';
    }
    return null;
  }

  static String? validateInitials(String? initials) {
    if (initials == null || initials.trim().isEmpty) return null;
    final trimmed = initials.trim();
    if (trimmed.length > 4) {
      return 'Initials must be 1-4 characters';
    }
    return null;
  }

  static String? validateGroup(String? group) {
    if (group == null || group.trim().isEmpty) return null;
    final trimmed = group.trim();
    if (trimmed.length > 25) {
      return 'Group name is too long (max 25 characters)';
    }
    return null;
  }

  String createRoster(String name) {
    final err = validateRosterName(name);
    if (err != null) throw ArgumentError(err);
    final id = _nextId('roster');
    final roster = Roster(id: id, name: name.trim());
    _rosters.add(roster);
    _selectedRosterId = id;
    notifyListeners();
    return id;
  }

  void renameRoster(String rosterId, String newName) {
    final err = validateRosterName(newName);
    if (err != null) throw ArgumentError(err);
    final idx = _rosters.indexWhere((r) => r.id == rosterId);
    if (idx != -1) {
      _rosters[idx] = _rosters[idx].copyWith(name: newName.trim());
      notifyListeners();
    }
  }

  void deleteRoster(String rosterId) {
    _rosters.removeWhere((r) => r.id == rosterId);
    if (_selectedRosterId == rosterId) {
      _selectedRosterId = _rosters.isNotEmpty ? _rosters.first.id : '';
    }
    notifyListeners();
  }

  void addStudent({
    required String rosterId,
    required String displayName,
    String? initials,
    String? group,
  }) {
    final errName = validateStudentDisplayName(displayName);
    if (errName != null) throw ArgumentError(errName);
    final errInit = validateInitials(initials);
    if (errInit != null) throw ArgumentError(errInit);
    final errGroup = validateGroup(group);
    if (errGroup != null) throw ArgumentError(errGroup);

    final idx = _rosters.indexWhere((r) => r.id == rosterId);
    if (idx == -1) return;

    final student = Student(
      id: _nextId('student'),
      displayName: displayName.trim(),
      initials: initials != null && initials.trim().isNotEmpty
          ? initials.trim()
          : null,
      group: group != null && group.trim().isNotEmpty ? group.trim() : null,
    );
    _rosters[idx] = _rosters[idx].addStudent(student);
    notifyListeners();
  }

  void updateStudent({required String rosterId, required Student student}) {
    final errName = validateStudentDisplayName(student.displayName);
    if (errName != null) throw ArgumentError(errName);
    final errInit = validateInitials(student.initials);
    if (errInit != null) throw ArgumentError(errInit);
    final errGroup = validateGroup(student.group);
    if (errGroup != null) throw ArgumentError(errGroup);

    final idx = _rosters.indexWhere((r) => r.id == rosterId);
    if (idx == -1) return;
    _rosters[idx] = _rosters[idx].updateStudent(student);
    notifyListeners();
  }

  void removeStudent({required String rosterId, required String studentId}) {
    final idx = _rosters.indexWhere((r) => r.id == rosterId);
    if (idx == -1) return;
    _rosters[idx] = _rosters[idx].removeStudent(studentId);
    notifyListeners();
  }

  void toggleStudentExclusion({
    required String rosterId,
    required String studentId,
  }) {
    final idx = _rosters.indexWhere((r) => r.id == rosterId);
    if (idx == -1) return;
    final s = _rosters[idx].students.firstWhere((st) => st.id == studentId);
    _rosters[idx] = _rosters[idx].setExcluded(studentId, !s.isExcluded);
    notifyListeners();
  }
}
