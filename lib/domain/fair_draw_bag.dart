/// Fair random picker using a draw-bag (shuffle-without-replacement).
///
/// Deterministic: the bag is derived from a user seed plus a fingerprint of
/// the eligible roster snapshot, so the same seed + same roster always
/// produces the same draw order, and any roster/exclusion change rebuilds
/// the bag reproducibly while signalling the caller (user-visible notice).
library;

import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'roster.dart';

/// Outcome status of a [FairDrawBag.draw] call.
enum BagStatus {
  /// A student was drawn normally from the current bag.
  drawn,

  /// The roster/exclusion set changed since the bag was built; the bag was
  /// deterministically rebuilt and a student was drawn from the new bag.
  /// The UI must surface this as an explicit reshuffle notice.
  rebuilt,

  /// No eligible students — the bag is empty (either nothing eligible at
  /// all, or the current bag is exhausted and waiting for a refill).
  empty,
}

/// Result of a single draw attempt.
class DrawOutcome {
  const DrawOutcome._(this.student, this.status, this.remainingInBag);

  const DrawOutcome.empty(int remaining)
    : student = null,
      status = BagStatus.empty,
      remainingInBag = remaining;

  /// The drawn student, or null when [status] is [BagStatus.empty].
  final Student? student;
  final BagStatus status;

  /// How many draws remain in the bag *after* this call.
  final int remainingInBag;

  bool get isDrawn => student != null;
}

/// Deterministic seed derivation: 32-bit FNV-1a over the seed and the
/// eligible-set fingerprint, so identical inputs give identical bags on
/// every platform (String.hashCode is not spec-stable; this is).
int _deriveSeed(int seed, String fingerprint) {
  const fnvOffset = 0x811c9dc5;
  const fnvPrime = 0x01000193;
  var h = fnvOffset;
  final bytes = utf8.encode(fingerprint);
  for (final b in bytes) {
    h ^= b;
    h = (h * fnvPrime) & 0xFFFFFFFF;
  }
  h ^= seed & 0xFFFFFFFF;
  h = (h * fnvPrime) & 0xFFFFFFFF;
  return h;
}

String _fingerprintOf(Roster roster) {
  final ids = roster.eligibleStudents.map((s) => s.id).toList()..sort();
  return '${roster.id}|${ids.join(",")}';
}

/// A fair draw bag over the eligible students of a [Roster].
///
/// Invariant (property-tested): within one bag generation no student can be
/// drawn twice, and every eligible student is drawn before the bag empties.
class FairDrawBag {
  FairDrawBag({required this._seed, required Roster roster}) {
    _build(roster);
  }

  final int _seed;
  final Queue<String> _queue = Queue<String>();
  String _fingerprint = '';
  int _generation = 0;
  bool _exhaustedNoticePending = false;

  /// Monotonic counter of bag generations; increments whenever the bag is
  /// (re)built. Useful for tests and for change-detection in the UI.
  int get generation => _generation;

  /// Ids still waiting to be drawn in the current bag, in draw order.
  List<String> get remainingIds => List.unmodifiable(_queue);

  /// True when the current bag has been emptied; the next draw on an
  /// unchanged roster rebuilds automatically (everyone drew once, now a new
  /// rotation begins deterministically from the same seed).
  bool get isExhausted => _exhaustedNoticePending;

  void _build(Roster roster) {
    _fingerprint = _fingerprintOf(roster);
    final ids = roster.eligibleStudents.map((s) => s.id).toList();
    final rng = Random(_deriveSeed(_seed, _fingerprint));
    // Fisher–Yates shuffle.
    for (var i = ids.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = ids[i];
      ids[i] = ids[j];
      ids[j] = tmp;
    }
    _queue
      ..clear()
      ..addAll(ids);
    _generation++;
    _exhaustedNoticePending = false;
  }

  /// Draw the next student from [roster]'s eligible set.
  ///
  /// If the eligible set changed since the bag was built, the bag is
  /// rebuilt deterministically for the new set and the outcome status is
  /// [BagStatus.rebuilt] — the UI must tell the teacher a reshuffle
  /// happened; nothing is ever silently skipped or duplicated.
  DrawOutcome draw(Roster roster) {
    final fp = _fingerprintOf(roster);
    var status = BagStatus.drawn;
    if (fp != _fingerprint) {
      _build(roster);
      status = BagStatus.rebuilt;
    } else if (_queue.isEmpty) {
      if (_exhaustedNoticePending) {
        // Rotation completed: begin the next rotation of the same
        // eligible set. Same seed+fingerprint gives the same order; the
        // rebuild status is the signal that a new rotation started.
        _build(roster);
        status = BagStatus.rebuilt;
      } else {
        _exhaustedNoticePending = true;
        return DrawOutcome.empty(0);
      }
    }

    if (_queue.isEmpty) {
      // Roster has zero eligible students (rebuilt onto an empty set).
      return DrawOutcome.empty(0);
    }

    final id = _queue.removeFirst();
    final student = roster.students.firstWhere((s) => s.id == id);
    if (_queue.isEmpty) {
      _exhaustedNoticePending = true;
    }
    return DrawOutcome._(student, status, _queue.length);
  }
}
