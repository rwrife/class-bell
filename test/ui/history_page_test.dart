import 'package:class_bell/domain/roster.dart';
import 'package:class_bell/main.dart';
import 'package:class_bell/repository/bell_repository.dart';
import 'package:class_bell/state/roster_store.dart';
import 'package:class_bell/ui/history_page.dart';
import 'package:flutter/foundation.dart';
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
  void close() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HistoryPage renders empty state and privacy notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: HistoryPage(history: []),
      ),
    );
    expect(find.byKey(const Key('history-privacy-note')), findsOneWidget);
    expect(find.byKey(const Key('history-empty')), findsOneWidget);
  });

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
