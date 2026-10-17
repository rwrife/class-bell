import 'package:flutter/material.dart';

void main() {
  runApp(const ClassBellApp());
}

/// Bootstrap shell. The platform-adaptive UI (Fluent / Material 3 /
/// Cupertino, PLAN.md strategy A) lands in a later milestone.
class ClassBellApp extends StatelessWidget {
  const ClassBellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Class Bell',
      home: const Scaffold(
        body: Center(child: Text('Class Bell', key: Key('app-title'))),
      ),
    );
  }
}
