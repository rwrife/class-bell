import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../domain/roster.dart';
import 'bell_repository.dart';

/// One local SQLite file, no background sync or per-student history.
class SqliteBellRepository implements BellRepository {
  SqliteBellRepository(String path) : _db = sqlite3.open(path) {
    final version = _db.userVersion;
    if (version > 2) {
      _db.close();
      throw StateError(
        'Class Bell database is from a newer version ($version)',
      );
    }
    try {
      _db.execute('BEGIN IMMEDIATE');
      if (version < 1) {
        _db.execute(
          'CREATE TABLE state (id INTEGER PRIMARY KEY CHECK(id = 1), json TEXT NOT NULL)',
        );
      }
      if (version < 2) {
        _db.execute('''CREATE TABLE day_totals (
          day TEXT PRIMARY KEY,
          praise_points INTEGER NOT NULL DEFAULT 0,
          focus_seconds INTEGER NOT NULL DEFAULT 0
        )''');
      }
      _db.userVersion = 2;
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      _db.close();
      rethrow;
    }
  }

  final Database _db;

  @override
  BellSnapshot load() {
    final rows = _db.select('SELECT json FROM state WHERE id = 1');
    if (rows.isEmpty) return const BellSnapshot();
    final data =
        jsonDecode(rows.single['json'] as String) as Map<String, dynamic>;
    final praise = (data['praiseByRoster'] as Map<String, dynamic>? ?? {});
    return BellSnapshot(
      rosters: (data['rosters'] as List<dynamic>? ?? [])
          .map((e) => Roster.fromJson(e as Map<String, dynamic>))
          .toList(),
      selectedRosterId: data['selectedRosterId'] as String? ?? '',
      presetMinutes: data['presetMinutes'] as int? ?? 5,
      goal: data['goal'] as int? ?? 20,
      quietSound: data['quietSound'] as bool? ?? false,
      unlockComboIndex: data['unlockComboIndex'] as int? ?? 0,
      praiseByRoster: praise.map(
        (key, value) => MapEntry(key, value as Map<String, dynamic>),
      ),
    );
  }

  @override
  void save(BellSnapshot snapshot) {
    final data = {
      'rosters': snapshot.rosters.map((r) => r.toJson()).toList(),
      'selectedRosterId': snapshot.selectedRosterId,
      'presetMinutes': snapshot.presetMinutes,
      'goal': snapshot.goal,
      'quietSound': snapshot.quietSound,
      'unlockComboIndex': snapshot.unlockComboIndex,
      'praiseByRoster': snapshot.praiseByRoster,
    };
    _db.execute('INSERT OR REPLACE INTO state(id, json) VALUES (1, ?)', [
      jsonEncode(data),
    ]);
  }

  // Date is local to classroom. The caller injects timestamps in tests.
  String _day(DateTime when) {
    final local = when.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  @override
  void recordFocus(DateTime when, int seconds) {
    if (seconds <= 0) return;
    _db.execute(
      '''INSERT INTO day_totals(day, focus_seconds) VALUES (?, ?)
      ON CONFLICT(day) DO UPDATE SET focus_seconds = focus_seconds + excluded.focus_seconds''',
      [_day(when), seconds],
    );
  }

  @override
  void recordPraise(DateTime when, int delta) {
    if (delta == 0) return;
    _db.execute(
      '''INSERT INTO day_totals(day, praise_points) VALUES (?, ?)
      ON CONFLICT(day) DO UPDATE SET praise_points = praise_points + excluded.praise_points''',
      [_day(when), delta],
    );
  }

  @override
  List<DaySummary> history() => _db
      .select(
        'SELECT day, praise_points, focus_seconds FROM day_totals ORDER BY day DESC',
      )
      .map(
        (row) => DaySummary(
          row['day'] as String,
          row['praise_points'] as int,
          row['focus_seconds'] as int,
        ),
      )
      .toList();

  @override
  void close() => _db.close();
}
