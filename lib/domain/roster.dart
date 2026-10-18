/// Pure Dart domain model for class rosters and student entries.
///
/// Privacy-first by design: display name (first name or alias), optional
/// initials, and group/class tags only. Never stores last names, emails,
/// photos, grades, attendance, or discipline/behavioral records.
class Student {
  const Student({
    required this.id,
    required this.displayName,
    this.initials,
    this.group,
    this.isExcluded = false,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      initials: json['initials'] as String?,
      group: json['group'] as String?,
      isExcluded: (json['isExcluded'] as bool?) ?? false,
    );
  }

  /// Unique stable identifier for this student within the local device.
  final String id;

  /// Display name (first name or alias/nickname).
  final String displayName;

  /// Optional initials (e.g. "A." or "JR") for disambiguation.
  final String? initials;

  /// Optional group/table tag (e.g. "Table 1", "Blue Group").
  final String? group;

  /// Whether this student is currently excluded from random draws (e.g. absent).
  final bool isExcluded;

  Student copyWith({
    String? id,
    String? displayName,
    String? initials,
    String? group,
    bool? isExcluded,
  }) {
    return Student(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      initials: initials ?? this.initials,
      group: group ?? this.group,
      isExcluded: isExcluded ?? this.isExcluded,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    if (initials != null) 'initials': initials,
    if (group != null) 'group': group,
    'isExcluded': isExcluded,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Student &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          initials == other.initials &&
          group == other.group &&
          isExcluded == other.isExcluded;

  @override
  int get hashCode => Object.hash(id, displayName, initials, group, isExcluded);

  @override
  String toString() =>
      'Student($id, $displayName, initials: $initials, group: $group, excluded: $isExcluded)';
}

/// A named classroom roster containing privacy-conscious student entries.
class Roster {
  const Roster({
    required this.id,
    required this.name,
    this.students = const [],
  });

  factory Roster.fromJson(Map<String, dynamic> json) {
    return Roster(
      id: json['id'] as String,
      name: json['name'] as String,
      students:
          (json['students'] as List<dynamic>?)
              ?.map((e) => Student.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  final String id;
  final String name;
  final List<Student> students;

  /// Students eligible for random selection (not excluded).
  List<Student> get eligibleStudents =>
      students.where((s) => !s.isExcluded).toList(growable: false);

  /// Unique set of groups present in this roster, preserving discovery order.
  List<String> get groups {
    final seen = <String>{};
    final list = <String>[];
    for (final s in students) {
      final g = s.group;
      if (g != null && g.trim().isNotEmpty && seen.add(g)) {
        list.add(g);
      }
    }
    return List.unmodifiable(list);
  }

  Roster copyWith({String? id, String? name, List<Student>? students}) {
    return Roster(
      id: id ?? this.id,
      name: name ?? this.name,
      students: students != null ? List.unmodifiable(students) : this.students,
    );
  }

  Roster addStudent(Student student) {
    final next = List<Student>.from(students)..add(student);
    return copyWith(students: next);
  }

  Roster updateStudent(Student student) {
    final next = students.map((s) => s.id == student.id ? student : s).toList();
    return copyWith(students: next);
  }

  Roster removeStudent(String studentId) {
    final next = students.where((s) => s.id != studentId).toList();
    return copyWith(students: next);
  }

  Roster setExcluded(String studentId, bool excluded) {
    final next = students
        .map((s) => s.id == studentId ? s.copyWith(isExcluded: excluded) : s)
        .toList();
    return copyWith(students: next);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'students': students.map((s) => s.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Roster &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          _listEquals(students, other.students);

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(students));

  static bool _listEquals(List<Student> a, List<Student> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
