import 'package:class_bell/backup/portable_backup.dart';
import 'package:class_bell/domain/roster.dart';
import 'package:class_bell/main.dart';
import 'package:class_bell/repository/bell_repository.dart';
import 'package:class_bell/state/roster_store.dart';
import 'package:class_bell/state/tool_session.dart';
import 'package:class_bell/ui/history_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements BellRepository {
  _FakeRepository(this._history);

  final List<DaySummary> _history;
  BellSnapshot _snapshot = const BellSnapshot();

  @override
  BellSnapshot load() => _snapshot;

  @override
  void save(BellSnapshot snapshot) => _snapshot = snapshot;

  @override
  void recordFocus(DateTime when, int seconds) {}

  @override
  void recordPraise(DateTime when, int delta) {}

  @override
  List<DaySummary> history() => List.unmodifiable(_history);

  @override
  void clearAll() {
    _snapshot = const BellSnapshot();
    _history.clear();
  }

  @override
  void restore(BellSnapshot snapshot, List<DaySummary> days) {
    _snapshot = snapshot;
    _history
      ..clear()
      ..addAll(days);
  }

  @override
  void close() {}
}

class _FakeFilePicker extends FilePicker {
  int clears = 0;

  @override
  Future<bool?> clearTemporaryFiles() async {
    clears++;
    return true;
  }
}

class _FakeBackupServices implements BackupServices {
  _FakeBackupServices(this.source);

  String? source;

  @override
  Future<ExportOutcome> saveDocument({
    required String fileName,
    required String content,
    required String label,
  }) async => const ExportOutcome(succeeded: true, savedPath: '/tmp/x');

  @override
  Future<String?> openDocument() async => source;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HistoryPage renders empty state and privacy notice', (
    tester,
  ) async {
    final repo = _FakeRepository(const []);
    final store = RosterStore(repository: repo);
    addTearDown(store.dispose);
    final session = ToolSession(store, repository: repo);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: HistoryPage(session: session),
      ),
    );
    expect(find.byKey(const Key('history-privacy-note')), findsOneWidget);
    expect(find.byKey(const Key('history-empty')), findsOneWidget);
  });

  testWidgets(
    'restore confirmation gates overwrite; delete confirmation gates wipe',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeRepository([]);
      final store = RosterStore(repository: repo);
      addTearDown(store.dispose);
      final rosterId = store.createRoster('Room 7');
      store.addStudent(rosterId: rosterId, displayName: 'Nia');
      final session = ToolSession(store, repository: repo);
      addTearDown(session.dispose);
      session.setGoal(15);
      session.praisePoint(null);
      final saved = backupJson(repo.load(), repo.history());
      store.createRoster('Room 8');
      session.setGoal(99);
      final services = _FakeBackupServices(saved);
      final picker = _FakeFilePicker();
      FilePicker.platform = picker;

      await tester.pumpWidget(
        material.MaterialApp(
          home: material.Scaffold(
            body: HistoryPage(session: session, services: services),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> tapAction(String key) async {
        final target = find.byKey(Key(key));
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await tapAction('import-backup');
      expect(find.text('Replace all local data?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.rosters.map((r) => r.name), ['Room 7', 'Room 8']);
      expect(session.goal, 99);

      await tapAction('import-backup');
      await tester.tap(find.byKey(const Key('dialog-submit')));
      await tester.pumpAndSettle();
      expect(store.rosters.map((r) => r.name), ['Room 7']);
      expect(session.goal, 15);
      expect(session.praise.classPoints, 1);
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      await tapAction('delete-all');
      expect(find.text('Delete all local data?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.rosters, hasLength(1));

      await tapAction('delete-all');
      await tester.tap(find.byKey(const Key('dialog-submit')));
      await tester.pumpAndSettle();
      expect(store.rosters, isEmpty);
      expect(repo.history(), isEmpty);
      expect(picker.clears, 1);
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      debugDefaultTargetPlatformOverride = null;
    },
  );

  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    testWidgets('$platform opens history and displays aggregate totals', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = platform == TargetPlatform.windows
          ? const Size(1280, 720)
          : const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeRepository([
        const DaySummary('2026-10-21', 14, 720),
        const DaySummary('2026-10-20', 5, 300),
      ]);
      final store = RosterStore(
        repository: repo,
        initialRosters: [
          Roster(
            id: 'room-1',
            name: 'Room 1',
            students: const [Student(id: 's1', displayName: 'Sam')],
          ),
        ],
      );
      addTearDown(store.dispose);

      await tester.pumpWidget(
        ClassBellApp(rosterStore: store, ownedRepository: repo),
      );
      await tester.pumpAndSettle();

      // Navigate to Praise tab.
      final praiseNav = find.text('Praise');
      await tester.tap(praiseNav.first);
      await tester.pumpAndSettle();

      // Tap History action.
      final historyBtn = find.byKey(const Key('praise-history'));
      expect(historyBtn, findsOneWidget);
      await tester.tap(historyBtn);
      await tester.pumpAndSettle();

      // History page is presented.
      expect(find.byKey(const Key('history-list')), findsOneWidget);
      expect(find.byKey(const Key('history-privacy-note')), findsOneWidget);
      expect(find.byKey(const Key('history-day-2026-10-21')), findsOneWidget);
      expect(find.byKey(const Key('history-day-2026-10-20')), findsOneWidget);
      expect(
        find.textContaining('14 praise points · 12 focus minutes'),
        findsOneWidget,
      );

      // Dismiss / pop back.
      if (platform == TargetPlatform.windows) {
        await tester.tap(find.byKey(const Key('history-close')));
      } else {
        await tester.pageBack();
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-list')), findsNothing);

      debugDefaultTargetPlatformOverride = null;
    });
  }
}
