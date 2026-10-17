import 'package:class_bell/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shell shows the Class Bell title', (tester) async {
    await tester.pumpWidget(const ClassBellApp());
    expect(find.byKey(const Key('app-title')), findsOneWidget);
    expect(find.text('Class Bell'), findsOneWidget);
  });
}
