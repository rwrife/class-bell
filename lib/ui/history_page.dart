import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';

import '../repository/bell_repository.dart';
import 'adaptive.dart';

/// Aggregate day history. No student-level records or per-person scores.
class HistoryPage extends StatelessWidget {
  const HistoryPage({required this.history, super.key});

  final List<DaySummary> history;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('history-list'),
    padding: const EdgeInsets.all(18),
    children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text(
          'Daily totals only. No student-level history is recorded.',
          key: Key('history-privacy-note'),
        ),
      ),
      if (history.isEmpty)
        const Text('No sessions recorded yet.', key: Key('history-empty')),
      for (final day in history)
        AdaptiveTile(
          key: Key('history-day-${day.day}'),
          title: day.day,
          semanticLabel:
              '${day.day}: ${day.praisePoints} praise points, ${day.focusMinutes} focus minutes',
          subtitle:
              '${day.praisePoints} praise points · ${day.focusMinutes} focus minutes',
        ),
    ],
  );
}

Future<void> showHistory(BuildContext context, List<DaySummary> history) {
  final page = HistoryPage(history: history);
  switch (bellPlatform(context)) {
    case BellPlatform.windows:
      return Navigator.of(context).push<void>(
        PageRouteBuilder(
          pageBuilder: (ctx, _, _) => AdaptiveScaffold(
            title: 'History',
            body: page,
            action: AdaptiveButton(
              key: const Key('history-close'),
              label: 'Back',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
        ),
      );
    case BellPlatform.ios:
      return Navigator.of(context).push<void>(
        cupertino.CupertinoPageRoute(
          builder: (_) => cupertino.CupertinoPageScaffold(
            navigationBar: const cupertino.CupertinoNavigationBar(
              middle: Text('History'),
            ),
            child: SafeArea(child: page),
          ),
        ),
      );
    case BellPlatform.android:
      return Navigator.of(context).push<void>(
        material.MaterialPageRoute(
          builder: (_) => material.Scaffold(
            appBar: material.AppBar(title: const Text('History')),
            body: page,
          ),
        ),
      );
  }
}
