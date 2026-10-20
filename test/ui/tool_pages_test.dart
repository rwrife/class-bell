import 'package:class_bell/domain/roster.dart';
import 'package:class_bell/main.dart';
import 'package:class_bell/state/roster_store.dart';
import 'package:class_bell/ui/tools/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

String? progress(WidgetTester tester) => tester
    .widgetList<Text>(
      find.byKey(const Key('praise-progress'), skipOffstage: false),
    )
    .last
    .data;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final roster = Roster(
    id: 'class',
    name: 'Blue class',
    students: const [
      Student(id: 'a', displayName: 'Ari', group: 'Blue'),
      Student(id: 'b', displayName: 'Bea', group: 'Blue'),
    ],
  );

  Future<void> openTool(
    WidgetTester tester,
    TargetPlatform platform,
    int index, {
    Size size = const Size(1280, 720),
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = RosterStore(initialRosters: [roster]);
    addTearDown(store.dispose);
    await tester.pumpWidget(ClassBellApp(rosterStore: store));
    await tester.pumpAndSettle();
    final names = ['Classes', 'Timer', 'Picker', 'Praise', 'Quiet'];
    // Desktop has a nav pane; mobile has a bottom navigation bar.
    final targets = find.text(names[index]);
    await tester.tap(targets.first);
    await tester.pumpAndSettle();
  }

  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    final size = platform == TargetPlatform.windows
        ? const Size(1280, 720)
        : const Size(360, 640);

    testWidgets('$platform timer: presets, pause, dim, projector lock', (
      tester,
    ) async {
      await openTool(tester, platform, 1, size: size);
      expect(find.byKey(const Key('countdown')), findsOneWidget);
      await tester.tap(find.byKey(const Key('preset-1')));
      await tester.pump();
      expect(find.text('1:00'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('timer-toggle')));
      await tester.tap(find.byKey(const Key('timer-toggle')));
      await tester.pump();
      expect(find.text('Pause'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('timer-toggle')));
      await tester.tap(find.byKey(const Key('timer-toggle')));
      await tester.pump();
      expect(find.text('Resume'), findsOneWidget);
      await tester.tap(find.byKey(const Key('timer-dim')));
      await tester.pump();
      expect(find.text('Brighten'), findsOneWidget);
      await tester.tap(find.byKey(const Key('projector-enter')));
      await tester.pump();
      expect(find.byKey(const Key('lock-chip')), findsOneWidget);
      expect(find.byKey(const Key('preset-1')), findsNothing);
      expect(find.byKey(const Key('leave-projector')), findsNothing);
      await tester.longPress(find.byKey(const Key('lock-chip')));
      await tester.pump();
      expect(find.byKey(const Key('leave-projector')), findsOneWidget);
      await tester.tap(find.byKey(const Key('leave-projector')));
      await tester.pump();
      expect(find.byKey(const Key('projector-enter')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 150));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('$platform picker: rotation and exclusions', (tester) async {
      await openTool(tester, platform, 2, size: size);
      expect(find.text('No repeats until everyone has a turn'), findsOneWidget);
      await tester.tap(find.byKey(const Key('picker-next')));
      await tester.pumpAndSettle();
      expect(find.text('1 left before anyone repeats'), findsOneWidget);
      await tester.tap(find.byKey(const Key('picker-next')));
      await tester.pumpAndSettle();
      expect(
        find.text('Rotation complete — everyone had a turn'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('picker-next')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Rotation rebuilt'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 150));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('$platform praise: class/group +/- and reset', (tester) async {
      await openTool(tester, platform, 3, size: size);
      expect(progress(tester), '0 / 20');
      if (platform != TargetPlatform.windows) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -180));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(
        find.byKey(const Key('praise-plus-Whole class')),
      );
      await tester.tap(find.byKey(const Key('praise-plus-Whole class')));
      await tester.pump();
      expect(progress(tester), '1 / 20');
      await tester.ensureVisible(find.byKey(const Key('praise-plus-Blue')));
      await tester.tap(find.byKey(const Key('praise-plus-Blue')));
      await tester.pump();
      expect(progress(tester), '2 / 20');
      await tester.ensureVisible(find.byKey(const Key('praise-minus-Blue')));
      await tester.tap(find.byKey(const Key('praise-minus-Blue')));
      await tester.pump();
      expect(progress(tester), '1 / 20');
      if (find.byKey(const Key('praise-reset')).evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          find.byKey(const Key('praise-reset')),
          200,
          scrollable: find.byType(Scrollable).last,
        );
      }
      await tester.ensureVisible(find.byKey(const Key('praise-reset')));
      await tester.tap(find.byKey(const Key('praise-reset')));
      await tester.pumpAndSettle();
      expect(find.text('Reset praise session?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 150));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('$platform quiet cue and optional sound toggle', (
      tester,
    ) async {
      await openTool(tester, platform, 4, size: size);
      expect(find.byKey(const Key('quiet-title')), findsOneWidget);
      expect(find.text('Sound off'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('quiet-sound')));
      await tester.tap(find.byKey(const Key('quiet-sound')));
      await tester.pump();
      expect(find.text('Sound on'), findsOneWidget);
      expect(find.byKey(const Key('quiet-backdrop')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 150));
      debugDefaultTargetPlatformOverride = null;
    });
  }

  test('countdown formatter clamps negative and pads seconds', () {
    expect(formatCountdown(const Duration(seconds: 125)), '2:05');
    expect(formatCountdown(const Duration(seconds: -10)), '0:00');
  });
}
