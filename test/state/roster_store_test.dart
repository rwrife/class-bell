import 'package:class_bell/state/roster_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts empty with no seeded students', () {
    final store = RosterStore();
    expect(store.rosters, isEmpty);
    expect(store.selectedRoster, isNull);
  });

  test('creates, renames, and deletes classes', () {
    final store = RosterStore();
    final id = store.createRoster('  Room 4  ');
    expect(store.selectedRoster!.name, 'Room 4');
    store.renameRoster(id, 'Room 5');
    expect(store.rosters.single.name, 'Room 5');
    store.deleteRoster(id);
    expect(store.rosters, isEmpty);
    expect(store.selectedRosterId, '');
  });

  test('multiple classes keep independent rosters and unique ids', () {
    final store = RosterStore();
    final a = store.createRoster('A');
    final b = store.createRoster('B');
    expect(a, isNot(b));
    store.addStudent(rosterId: a, displayName: 'Ana');
    store.addStudent(rosterId: b, displayName: 'Ben');
    store.addStudent(rosterId: b, displayName: 'Bea');
    expect(store.rosters.first.students.length, 1);
    expect(store.rosters.last.students.length, 2);
    final ids = store.rosters.expand((r) => r.students).map((s) => s.id);
    expect(ids.toSet().length, 3);
  });

  test('rejects empty, overlong, and email-like names', () {
    final store = RosterStore();
    final id = store.createRoster('A');
    expect(
      () => store.addStudent(rosterId: id, displayName: '  '),
      throwsArgumentError,
    );
    expect(
      () => store.addStudent(rosterId: id, displayName: 'x' * 26),
      throwsArgumentError,
    );
    expect(
      () => store.addStudent(rosterId: id, displayName: 'kid@school.org'),
      throwsArgumentError,
    );
    expect(
      () =>
          store.addStudent(rosterId: id, displayName: 'Al', initials: 'ABCDE'),
      throwsArgumentError,
    );
    expect(store.rosters.single.students, isEmpty);
  });

  test('exclusion toggle and removal notify listeners', () {
    final store = RosterStore();
    final id = store.createRoster('A');
    store.addStudent(rosterId: id, displayName: 'Ana');
    var notified = 0;
    store.addListener(() => notified++);
    final sid = store.rosters.single.students.single.id;
    store.toggleStudentExclusion(rosterId: id, studentId: sid);
    expect(store.rosters.single.students.single.isExcluded, isTrue);
    store.removeStudent(rosterId: id, studentId: sid);
    expect(store.rosters.single.students, isEmpty);
    expect(notified, 2);
  });
}
