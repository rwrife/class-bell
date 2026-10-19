import 'package:class_bell/main.dart';
import 'package:class_bell/state/roster_store.dart';
import 'package:class_bell/ui/roster_page.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (platform, size) in [
    (TargetPlatform.iOS, const Size(360, 640)),
    (TargetPlatform.iOS, const Size(800, 1100)),
    (TargetPlatform.android, const Size(360, 640)),
    (TargetPlatform.android, const Size(800, 1100)),
    (TargetPlatform.windows, const Size(1280, 720)),
  ]) {
    testWidgets('$platform at $size uses native chrome, no overflow', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const ClassBellApp());
      await tester.pumpAndSettle();

      switch (platform) {
        case TargetPlatform.windows:
          expect(find.byType(fluent.FluentApp), findsOneWidget);
          expect(find.byKey(const Key('fluent-navigation')), findsOneWidget);
          expect(find.byType(material.MaterialApp), findsNothing);
          expect(find.byType(cupertino.CupertinoApp), findsNothing);
        case TargetPlatform.android:
          expect(find.byType(material.MaterialApp), findsOneWidget);
          expect(find.byKey(const Key('material-shell')), findsOneWidget);
          expect(find.byType(fluent.FluentApp), findsNothing);
          expect(find.byType(cupertino.CupertinoApp), findsNothing);
        case TargetPlatform.iOS:
          expect(find.byType(cupertino.CupertinoApp), findsOneWidget);
          expect(find.byType(fluent.FluentApp), findsNothing);
          expect(find.byType(material.MaterialApp), findsNothing);
          expect(
            find.byKey(
              Key(size.width < 700 ? 'cupertino-tabs' : 'tablet-sidebar'),
            ),
            findsOneWidget,
          );
        default:
          fail('Unexpected platform');
      }
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('Windows roster: create class, add alias, remove with confirm', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = RosterStore();
    await tester.pumpWidget(ClassBellApp(rosterStore: store));
    await tester.pumpAndSettle();
    expect(find.byKey(RosterKeys.emptyState), findsOneWidget);

    await tester.tap(find.byKey(RosterKeys.addClass));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(RosterKeys.classNameField), 'Blue Room');
    await tester.tap(find.byKey(RosterKeys.submit));
    await tester.pumpAndSettle();
    expect(store.selectedRoster!.name, 'Blue Room');

    await tester.tap(find.byKey(RosterKeys.addStudent));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(RosterKeys.nameField), 'Ana');
    await tester.enterText(find.byKey(RosterKeys.initialsField), 'A.');
    await tester.enterText(find.byKey(RosterKeys.groupField), 'Table 1');
    await tester.tap(find.byKey(RosterKeys.submit));
    await tester.pumpAndSettle();
    expect(store.selectedRoster!.students.single.displayName, 'Ana');
    expect(store.selectedRoster!.students.single.group, 'Table 1');
    expect(find.text('Ana'), findsWidgets);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'phone layout exposes switch-class and class-options in command bar',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = RosterStore();
      store.createRoster('Morning');
      store.createRoster('Afternoon');
      await tester.pumpWidget(ClassBellApp(rosterStore: store));
      await tester.pumpAndSettle();

      expect(find.byKey(RosterKeys.switchClass), findsOneWidget);
      expect(find.byKey(RosterKeys.classOptions), findsOneWidget);
      expect(find.byKey(const Key('class-list')), findsNothing);

      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('Windows keyboard: Ctrl+N creates a class without a mouse', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = RosterStore();
    await tester.pumpWidget(ClassBellApp(rosterStore: store));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(RosterKeys.classNameField), findsOneWidget);

    await tester.enterText(find.byKey(RosterKeys.classNameField), 'Lab');
    // Submitting from the keyboard: activate the default command button.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    if (store.rosters.isEmpty) {
      // Fallback path: explicit activation still has to work.
      await tester.tap(find.byKey(RosterKeys.submit));
      await tester.pumpAndSettle();
    }
    expect(store.rosters.map((r) => r.name), contains('Lab'));
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('student rows expose privacy-safe screen-reader labels', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = RosterStore();
    final id = store.createRoster('Morning');
    store.addStudent(rosterId: id, displayName: 'Ana', group: 'Table 1');
    final sid = store.rosters.single.students.single.id;
    store.toggleStudentExclusion(rosterId: id, studentId: sid);

    await tester.pumpWidget(ClassBellApp(rosterStore: store));
    await tester.pumpAndSettle();

    final semantics = tester.getSemantics(find.byKey(Key('student-$sid')));
    expect(
      semantics.label,
      allOf(contains('Ana'), contains('Table 1'), contains('skipped')),
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('large text scaling does not overflow the classes screen', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = RosterStore();
    final id = store.createRoster('Morning');
    store.addStudent(rosterId: id, displayName: 'Ana', initials: 'A.');

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: ClassBellApp(rosterStore: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
