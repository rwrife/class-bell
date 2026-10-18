import 'package:class_bell/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PraiseSession', () {
    test('whole-class and group tallies accumulate toward one goal', () {
      final session = PraiseSession(goal: 50, groups: ['Blue', 'Green']);

      session.addClassPoints(10);
      session.addGroupPoints('Blue', 15);
      session.addGroupPoints('Green', 8);

      expect(session.classPoints, 10);
      expect(session.groupPoints('Blue'), 15);
      expect(session.totalGroupPoints, 23);
      expect(session.progress, 33);
      expect(session.goalReached, isFalse);
    });

    test('goal reached when class + group points meet the goal', () {
      final session = PraiseSession(goal: 20, groups: ['A']);
      session.addClassPoints(10);
      session.addGroupPoints('A', 10);
      expect(session.goalReached, isTrue);

      session.addGroupPoints('A', 5); // overshoot allowed, still reached
      expect(session.progress, 25);
    });

    test('per-session reset zeroes tallies and bumps session number', () {
      final session = PraiseSession(goal: 30, groups: ['Red', 'Gold']);
      session.addClassPoints(25);
      session.addGroupPoints('Gold', 4);

      session.resetSession();

      expect(session.classPoints, 0);
      expect(session.groupPoints('Red'), 0);
      expect(session.groupPoints('Gold'), 0);
      expect(session.progress, 0);
      expect(session.goalReached, isFalse);
      expect(session.sessionNumber, 2);
    });

    test('rejects non-positive points (praise board, not penalty board)', () {
      final session = PraiseSession(goal: 10, groups: ['X']);
      expect(() => session.addClassPoints(0), throwsArgumentError);
      expect(() => session.addClassPoints(-5), throwsArgumentError);
      expect(() => session.addGroupPoints('X', -1), throwsArgumentError);
    });

    test('rejects points for unknown groups', () {
      final session = PraiseSession(goal: 10, groups: ['X']);
      expect(() => session.addGroupPoints('Nope', 1), throwsArgumentError);
    });

    test('rejects non-positive goal', () {
      expect(
        () => PraiseSession(goal: 0, groups: []),
        throwsA(isA<AssertionError>()),
      );
    });

    test('round-trip JSON serialization preserves state', () {
      final session = PraiseSession(goal: 40, groups: ['Blue', 'Red']);
      session.addClassPoints(7);
      session.addGroupPoints('Blue', 3);
      session.addGroupPoints('Red', 2);

      final restored = PraiseSession.fromJson(session.toJson());
      expect(restored, equals(session));
      expect(restored.goal, 40);
      expect(restored.classPoints, 7);
      expect(restored.groupPoints('Blue'), 3);
      expect(restored.sessionNumber, 1);
    });

    test('privacy contract: serialization has no per-student keys', () {
      final session = PraiseSession(goal: 50, groups: ['Table 1']);
      session.addClassPoints(5);
      session.addGroupPoints('Table 1', 5);

      final json = session.toJson();
      expect(json.containsKey('studentPoints'), isFalse);
      expect(json.containsKey('perStudent'), isFalse);
      expect(json.containsKey('individualScores'), isFalse);
      expect(json.containsKey('discipline'), isFalse);

      // The only point buckets are the whole class and declared group labels.
      expect((json['groupPoints'] as Map).keys, ['Table 1']);
    });
  });
}
