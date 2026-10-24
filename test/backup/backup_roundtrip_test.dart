import 'dart:io';

import 'package:class_bell/backup/portable_backup.dart';
import 'package:class_bell/domain/roster.dart';
import 'package:class_bell/repository/bell_repository.dart';
import 'package:class_bell/repository/sqlite_bell_repository.dart';
import 'package:class_bell/state/roster_store.dart';
import 'package:class_bell/state/tool_session.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFilePicker extends FilePicker {
  int clears = 0;

  @override
  Future<bool?> clearTemporaryFiles() async {
    clears++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late String dbFile;
  late _FakeFilePicker picker;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('class-bell-backup-');
    dbFile = '${dir.path}/bell.sqlite3';
    picker = _FakeFilePicker();
    FilePicker.platform = picker;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('CSV exports omit student PII and format columns deterministically', () {
    final rosters = [
      Roster(
        id: 'r1',
        name: '4th Grade, Blue',
        students: const [
          Student(
            id: 's1',
            displayName: 'Ana',
            initials: 'A',
            group: 'Table 1',
          ),
          Student(id: 's2', displayName: 'Ben "Bubba"', isExcluded: true),
        ],
      ),
    ];
    final csv = rosterCsv(rosters);
    expect(
      csv,
      'class,name,initials,group,excluded\n'
      '"4th Grade, Blue",Ana,A,Table 1,no\n'
      '"4th Grade, Blue","Ben ""Bubba""",,,yes\n',
    );

    final history = [
      const DaySummary('2026-10-21', 14, 720),
      const DaySummary('2026-10-20', 0, 0),
    ];
    final histCsv = historyCsv(history);
    expect(
      histCsv,
      'day,praise_points,focus_seconds\n'
      '2026-10-21,14,720\n'
      '2026-10-20,0,0\n',
    );
  });

  test(
    'backup round-trip: export -> wipe -> restore reproduces identical state',
    () {
      var repo = SqliteBellRepository(dbFile);
      final store = RosterStore(repository: repo);
      final r1 = store.createRoster('Room 101');
      store.addStudent(rosterId: r1, displayName: 'Maya', group: 'G1');
      store.addStudent(rosterId: r1, displayName: 'Leo', initials: 'L');
      store.createRoster('Room 102');
      store.selectRoster(r1);

      final session = ToolSession(store, repository: repo);
      session.setPreset(18);
      session.setGoal(40);
      session.toggleQuietSound();
      session.cycleUnlockCombo();
      session.praisePoint('G1');
      session.praisePoint(null);
      repo.recordFocus(DateTime(2026, 10, 20), 480);
      session.dispose();
      store.dispose();

      // Export current state.
      final originalSnapshot = repo.load();
      final originalHistory = repo.history();
      final json = backupJson(originalSnapshot, originalHistory);

      // Delete-all wipe.
      repo.clearAll();
      expect(repo.load().rosters, isEmpty);
      expect(repo.history(), isEmpty);

      // Parse backup and restore.
      final parsed = parseBackup(json);
      repo.restore(parsed.snapshot, parsed.history);
      repo.close();

      // Reopen fresh to prove disk durability.
      repo = SqliteBellRepository(dbFile);
      final restoredSnap = repo.load();
      final restoredHistory = repo.history();

      expect(restoredSnap.rosters.map((r) => r.name), ['Room 101', 'Room 102']);
      expect(restoredSnap.selectedRosterId, r1);
      final restoredR1 = restoredSnap.rosters.firstWhere((r) => r.id == r1);
      expect(restoredR1.students.map((s) => s.displayName), ['Maya', 'Leo']);
      expect(restoredR1.students.first.group, 'G1');
      expect(restoredSnap.presetMinutes, 18);
      expect(restoredSnap.goal, 40);
      expect(restoredSnap.quietSound, isTrue);
      expect(restoredSnap.unlockComboIndex, 1);
      expect(restoredSnap.praiseByRoster[r1]!['classPoints'], 1);

      expect(restoredHistory.map((d) => d.day), containsAll(['2026-10-20']));
      final day20 = restoredHistory.firstWhere((d) => d.day == '2026-10-20');
      expect(day20.focusSeconds, 480);
      final praiseDays = restoredHistory.where((d) => d.praisePoints != 0);
      expect(praiseDays.fold(0, (sum, d) => sum + d.praisePoints), 2);

      repo.close();
    },
  );

  test(
    'corrupt backup handling: refuses foreign, invalid, or newer-schema files',
    () {
      expect(
        () => parseBackup('{not valid json'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => parseBackup('{"format": "other-app"}'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () =>
            parseBackup('{"format": "class-bell-backup", "schemaVersion": 99}'),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
      expect(
        () =>
            parseBackup('{"format": "class-bell-backup", "schemaVersion": 1}'),
        throwsA(isA<BackupFormatException>()),
      );
      // Missing required fields
      expect(
        () => parseBackup(
          '{"format": "class-bell-backup", "schemaVersion": 2, "rosters": []}',
        ),
        throwsA(isA<BackupFormatException>()),
      );
      // Duplicate history days
      expect(
        () => parseBackup('''{
        "format": "class-bell-backup",
        "schemaVersion": 2,
        "rosters": [],
        "selectedRosterId": "",
        "settings": {"presetMinutes": 5, "goal": 20, "quietSound": false, "unlockComboIndex": 0},
        "praiseByRoster": {},
        "history": [
          {"day": "2026-10-21", "praisePoints": 1, "focusSeconds": 10},
          {"day": "2026-10-21", "praisePoints": 2, "focusSeconds": 20}
        ]
      }'''),
        throwsA(isA<BackupFormatException>()),
      );
    },
  );

  test('delete-all clears DB and leaves user export files untouched', () async {
    final repo = SqliteBellRepository(dbFile);
    final store = RosterStore(repository: repo);
    store.createRoster('Wipe Me');
    repo.recordFocus(DateTime(2026, 10, 21), 60);
    store.dispose();

    // Teacher saved an export file to disk.
    final userExport = File('${dir.path}/my-saved-classes.csv');
    userExport.writeAsStringSync('class,name\nWipe Me,Sam\n');
    expect(userExport.existsSync(), isTrue);

    // Delete-all run.
    repo.clearAll();
    await clearAppOwnedCaches();
    expect(picker.clears, 1);

    // Verification: DB is empty.
    expect(repo.load().rosters, isEmpty);
    expect(repo.history(), isEmpty);

    // Verification: user-created export was NOT touched.
    expect(userExport.existsSync(), isTrue);
    expect(userExport.readAsStringSync(), 'class,name\nWipe Me,Sam\n');

    repo.close();
  });
}
