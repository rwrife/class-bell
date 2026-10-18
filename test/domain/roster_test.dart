import 'package:class_bell/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Student model', () {
    test('privacy contract: only stores display name, initials, and group', () {
      const s = Student(
        id: 's1',
        displayName: 'Aaliyah',
        initials: 'A.',
        group: 'Table 1',
      );

      final json = s.toJson();
      expect(json['id'], 's1');
      expect(json['displayName'], 'Aaliyah');
      expect(json['initials'], 'A.');
      expect(json['group'], 'Table 1');
      expect(json['isExcluded'], isFalse);

      // Explicitly assert absence of PII keys
      expect(json.containsKey('lastName'), isFalse);
      expect(json.containsKey('email'), isFalse);
      expect(json.containsKey('photo'), isFalse);
      expect(json.containsKey('grade'), isFalse);
      expect(json.containsKey('score'), isFalse);
      expect(json.containsKey('discipline'), isFalse);
    });

    test('round-trip JSON serialization', () {
      const original = Student(
        id: 's2',
        displayName: 'Bo',
        initials: 'B',
        group: 'Blue Group',
        isExcluded: true,
      );

      final restored = Student.fromJson(original.toJson());
      expect(restored, equals(original));
    });

    test('copyWith updates specified fields', () {
      const s = Student(id: 's3', displayName: 'Charlie');
      final updated = s.copyWith(isExcluded: true, group: 'Red');

      expect(updated.id, 's3');
      expect(updated.displayName, 'Charlie');
      expect(updated.isExcluded, isTrue);
      expect(updated.group, 'Red');
    });
  });

  group('Roster model', () {
    const s1 = Student(id: '1', displayName: 'Ava', group: 'Table 1');
    const s2 = Student(
      id: '2',
      displayName: 'Ben',
      group: 'Table 2',
      isExcluded: true,
    );
    const s3 = Student(id: '3', displayName: 'Cam', group: 'Table 1');

    test('filters eligible students (excludes absent/opted-out)', () {
      const roster = Roster(
        id: 'r1',
        name: 'Period 1 Math',
        students: [s1, s2, s3],
      );

      expect(roster.eligibleStudents.map((s) => s.displayName), ['Ava', 'Cam']);
    });

    test('extracts unique group labels in order', () {
      const roster = Roster(id: 'r1', name: 'Homeroom', students: [s1, s2, s3]);

      expect(roster.groups, ['Table 1', 'Table 2']);
    });

    test('add, update, remove, and toggle exclusion immutably', () {
      var r = const Roster(id: 'r1', name: 'Art', students: [s1]);
      expect(r.students.length, 1);

      r = r.addStudent(s3);
      expect(r.students.length, 2);

      r = r.setExcluded('1', true);
      expect(r.eligibleStudents.map((s) => s.id), ['3']);

      r = r.updateStudent(const Student(id: '3', displayName: 'Cameron'));
      expect(r.students.firstWhere((s) => s.id == '3').displayName, 'Cameron');

      r = r.removeStudent('1');
      expect(r.students.map((s) => s.id), ['3']);
    });

    test('round-trip JSON serialization', () {
      const original = Roster(
        id: 'r_full',
        name: 'Science 6A',
        students: [s1, s2, s3],
      );

      final restored = Roster.fromJson(original.toJson());
      expect(restored, equals(original));
    });
  });
}
