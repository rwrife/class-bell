import 'package:class_bell/main.dart';
import 'package:class_bell/ui/roster_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots into the Classes screen', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(const ClassBellApp());
    await tester.pumpAndSettle();
    expect(find.byKey(RosterKeys.emptyState), findsOneWidget);
    expect(find.text('Classes'), findsWidgets);
    debugDefaultTargetPlatformOverride = null;
  });
}
