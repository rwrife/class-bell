import 'package:class_bell/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Roster makeRoster(List<String> names, {Set<String> excluded = const {}}) {
    return Roster(
      id: 'r1',
      name: 'Class 4B',
      students: [
        for (var i = 0; i < names.length; i++)
          Student(
            id: 's_$i',
            displayName: names[i],
            isExcluded: excluded.contains(names[i]),
          ),
      ],
    );
  }

  group('FairDrawBag fairness and property tests', () {
    test('draws every eligible student without repeats until empty (property test)', () {
      final names = List.generate(24, (i) => 'Student_$i');
      final roster = makeRoster(names);
      final bag = FairDrawBag(seed: 42, roster: roster);

      final drawn = <String>[];
      for (var i = 0; i < names.length; i++) {
        final outcome = bag.draw(roster);
        expect(outcome.isDrawn, isTrue);
        expect(outcome.status, equals(BagStatus.drawn));
        expect(outcome.remainingInBag, equals(names.length - 1 - i));
        drawn.add(outcome.student!.displayName);
      }

      // Invariant 1: No duplicates across a single bag run
      expect(drawn.toSet().length, equals(names.length));
      // Invariant 2: Every single student was drawn
      expect(drawn.toSet(), equals(names.toSet()));

      // Next draw sees exhausted bag, then triggers rebuild for new rotation
      final next = bag.draw(roster);
      expect(next.status, equals(BagStatus.rebuilt));
      expect(next.isDrawn, isTrue);
    });

    test(
      'property: no repeats until exhaustion across 200 seeds and sizes',
      () {
        for (var seed = 0; seed < 200; seed++) {
          final n = 1 + seed % 40;
          final roster = makeRoster(List.generate(n, (i) => 'N$i'));
          final bag = FairDrawBag(seed: seed, roster: roster);
          final ids = <String>{};
          for (var i = 0; i < n; i++) {
            expect(
              ids.add(bag.draw(roster).student!.id),
              isTrue,
              reason: 'repeat at seed $seed draw $i',
            );
          }
          expect(ids.length, n);
        }
      },
    );

    test(
      'deterministic: same seed + same roster yields identical draw order',
      () {
        final names = ['Alice', 'Bob', 'Charlie', 'Daisy', 'Ethan', 'Fiona'];
        final r = makeRoster(names);

        final bag1 = FairDrawBag(seed: 1337, roster: r);
        final draws1 = [
          for (var i = 0; i < names.length; i++) bag1.draw(r).student!.id,
        ];

        final bag2 = FairDrawBag(seed: 1337, roster: r);
        final draws2 = [
          for (var i = 0; i < names.length; i++) bag2.draw(r).student!.id,
        ];

        expect(draws1, equals(draws2));
      },
    );

    test('different seeds yield different draw orders', () {
      final names = List.generate(30, (i) => 'S$i');
      final r = makeRoster(names);

      final bag1 = FairDrawBag(seed: 1, roster: r);
      final draws1 = [
        for (var i = 0; i < names.length; i++) bag1.draw(r).student!.id,
      ];

      final bag2 = FairDrawBag(seed: 2, roster: r);
      final draws2 = [
        for (var i = 0; i < names.length; i++) bag2.draw(r).student!.id,
      ];

      expect(draws1, isNot(equals(draws2)));
    });

    test('edge case: empty roster returns empty outcome', () {
      const empty = Roster(id: 'empty', name: 'Empty');
      final bag = FairDrawBag(seed: 1, roster: empty);

      final outcome = bag.draw(empty);
      expect(outcome.isDrawn, isFalse);
      expect(outcome.status, equals(BagStatus.empty));
      expect(outcome.remainingInBag, 0);
    });

    test('edge case: all students excluded returns empty outcome', () {
      final r = makeRoster(['A', 'B'], excluded: {'A', 'B'});
      final bag = FairDrawBag(seed: 1, roster: r);

      final outcome = bag.draw(r);
      expect(outcome.isDrawn, isFalse);
      expect(outcome.status, equals(BagStatus.empty));
    });

    test('roster change invalidates bag with BagStatus.rebuilt signal', () {
      final r1 = makeRoster(['A', 'B', 'C', 'D']);
      final bag = FairDrawBag(seed: 10, roster: r1);

      // Draw two students normally
      final first = bag.draw(r1);
      expect(first.status, equals(BagStatus.drawn));
      final second = bag.draw(r1);
      expect(second.status, equals(BagStatus.drawn));

      // Now add a 5th student to the roster mid-rotation
      final r2 = r1.addStudent(const Student(id: 's_4', displayName: 'E'));
      final afterChange = bag.draw(r2);

      // Invalidation MUST be signalled with BagStatus.rebuilt for user notification
      expect(afterChange.status, equals(BagStatus.rebuilt));
      expect(afterChange.isDrawn, isTrue);
    });

    test(
      'marking student excluded invalidates bag with BagStatus.rebuilt signal',
      () {
        final r1 = makeRoster(['A', 'B', 'C']);
        final bag = FairDrawBag(seed: 99, roster: r1);

        bag.draw(r1);

        // Student B calls in sick mid-rotation
        final r2 = r1.setExcluded('s_1', true);
        final outcome = bag.draw(r2);

        expect(outcome.status, equals(BagStatus.rebuilt));
        expect(outcome.isDrawn, isTrue);
        expect(outcome.student!.displayName, isNot('B'));
      },
    );
  });
}
