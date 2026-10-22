import 'dart:io';

import 'package:class_bell/repository/sqlite_bell_repository.dart';
import 'package:class_bell/state/roster_store.dart';
import 'package:class_bell/state/tool_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late String file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('class-bell-repo-');
    file = '${dir.path}/bell.sqlite3';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('rosters, selected class, settings and praise survive reopen', () {
    var repo = SqliteBellRepository(file);
    final store = RosterStore(repository: repo);
    final id = store.createRoster('Blue Room');
    store.addStudent(rosterId: id, displayName: 'Ana', group: 'Table 1');
    store.createRoster('Red Room');
    store.selectRoster(id);
    final session = ToolSession(store, repository: repo);
    session.setPreset(12);
    session.setGoal(50);
    session.toggleQuietSound();
    session.cycleUnlockCombo();
    session.praisePoint(null);
    session.praisePoint('Table 1');
    session.dispose();
    store.dispose();
    repo.close();

    repo = SqliteBellRepository(file);
    final reopened = RosterStore(repository: repo);
    final restored = ToolSession(reopened, repository: repo);
    expect(reopened.rosters.map((r) => r.name), ['Blue Room', 'Red Room']);
    expect(reopened.selectedRosterId, id);
    expect(reopened.selectedRoster!.students.single.displayName, 'Ana');
    expect(restored.presetMinutes, 12);
    expect(restored.goal, 50);
    expect(restored.quietSound, isTrue);
    expect(restored.unlockComboIndex, 1);
    expect(restored.praise.classPoints, 1);
    expect(restored.praise.groupPoints('Table 1'), 1);
    restored.dispose();
    reopened.dispose();
    repo.close();
  });

  test('reopen discards timer state and never invents elapsed time', () {
    var repo = SqliteBellRepository(file);
    final store = RosterStore(repository: repo);
    var elapsed = Duration.zero;
    var session = ToolSession(
      store,
      repository: repo,
      clock: () => elapsed,
      now: () => DateTime(2026, 10, 21),
    );
    session.setPreset(5);
    session.toggleTimer();
    elapsed = const Duration(seconds: 63);
    session.refresh();
    expect(repo.history().single.focusSeconds, 63);
    session.dispose();
    store.dispose();
    repo.close();

    repo = SqliteBellRepository(file);
    final reopened = RosterStore(repository: repo);
    session = ToolSession(
      reopened,
      repository: repo,
      clock: () => const Duration(hours: 999),
      now: () => DateTime(2026, 10, 23),
    );
    expect(session.snapshot.elapsed, Duration.zero);
    expect(repo.history().length, 1);
    expect(repo.history().single.focusSeconds, 63);
    expect(repo.history().single.day, '2026-10-21');
    session.dispose();
    reopened.dispose();
    repo.close();
  });

  test('v1 fixture migrates to v2 and preserves roster/settings', () {
    final db = sqlite3.open(file);
    db.execute(File('test/fixtures/schema_v1.sql').readAsStringSync());
    db.close();
    final repo = SqliteBellRepository(file);
    final snapshot = repo.load();
    expect(snapshot.rosters.single.name, 'Blue Room');
    expect(snapshot.rosters.single.students.single.displayName, 'Ana');
    expect(snapshot.presetMinutes, 12);
    expect(snapshot.goal, 50);
    repo.recordPraise(DateTime(2026, 10, 21), 3);
    expect(repo.history().single.praisePoints, 3);
    repo.close();
    final check = sqlite3.open(file);
    expect(check.userVersion, 2);
    check.close();
  });

  test('daily history contains aggregate corrections and focus only', () {
    final repo = SqliteBellRepository(file);
    final day = DateTime(2026, 10, 21);
    repo.recordFocus(day, 125);
    repo.recordPraise(day, 3);
    repo.recordPraise(day, -1);
    repo.recordFocus(DateTime(2026, 10, 22), 40);
    final history = repo.history();
    expect(history.map((d) => d.day), ['2026-10-22', '2026-10-21']);
    expect(history.last.praisePoints, 2);
    expect(history.last.focusMinutes, 2);
    expect(history.last.focusSeconds, 125);
    repo.close();
  });
}
