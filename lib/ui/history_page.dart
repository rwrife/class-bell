import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';

import '../backup/portable_backup.dart';
import '../repository/bell_repository.dart';
import '../state/tool_session.dart';
import 'adaptive.dart';

/// Aggregate day history with teacher-controlled portable data actions.
/// No student-level records or per-person scores.
class HistoryPage extends StatefulWidget {
  const HistoryPage({
    required this.session,
    this.services = const FilePickerBackupServices(),
    super.key,
  });

  final ToolSession session;
  final BackupServices services;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  BellRepository? get repository =>
      widget.session.store.repository ?? widget.session.repository;

  Future<void> _export({
    required String name,
    required String content,
    required String label,
  }) async {
    try {
      final result = await widget.services.saveDocument(
        fileName: name,
        content: content,
        label: label,
      );
      if (!mounted || !result.succeeded) return;
      await showAdaptiveNotice(
        context,
        'Export saved',
        '$label saved to your chosen location.',
      );
    } on Object catch (error) {
      if (mounted) await showAdaptiveNotice(context, 'Export failed', '$error');
    }
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showAdaptiveDialog<bool>(
        context: context,
        builder: (ctx) => AdaptiveDialog(
          title: title,
          content: Text(message),
          cancel: 'Cancel',
          confirm: action,
          onCancel: () => Navigator.of(ctx).pop(false),
          onConfirm: () => Navigator.of(ctx).pop(true),
        ),
      ) ??
      false;

  Future<void> _restore() async {
    final repo = repository;
    if (repo == null) return;
    try {
      final source = await widget.services.openDocument();
      if (source == null || !mounted) return;
      // Parse the whole file before prompting or writing anything. A corrupt
      // file must not touch current data.
      final data = parseBackup(source);
      if (!mounted ||
          !await _confirm(
            'Replace all local data?',
            'Restoring this backup replaces every class, setting, tally and day total on this device. Export current data first if you need it.',
            'Replace data',
          )) {
        return;
      }
      widget.session.flushForBackup();
      repo.restore(data.snapshot, data.history);
      widget.session.store.reload();
      widget.session.resetAfterDataChange();
      if (mounted) {
        setState(() {});
        await showAdaptiveNotice(
          context,
          'Backup restored',
          'Local data now matches the chosen backup.',
        );
      }
    } on Object catch (error) {
      if (mounted) {
        await showAdaptiveNotice(context, 'Restore failed', '$error');
      }
    }
  }

  Future<void> _deleteAll() async {
    final repo = repository;
    if (repo == null ||
        !await _confirm(
          'Delete all local data?',
          'All classes, settings, tallies and day history on this device will be erased. Files you exported yourself remain untouched. This cannot be undone.',
          'Delete all',
        )) {
      return;
    }
    try {
      widget.session.flushForBackup();
      repo.clearAll();
      // Reload UI state first: a cache-clearing failure must never leave the
      // store holding deleted rows in memory (a later save would resurrect
      // them).
      widget.session.store.reload();
      widget.session.resetAfterDataChange();
      // File picker caches temporary copies in its own app sandbox. Never
      // traverse user-chosen export paths: those files belong to the teacher.
      await clearAppOwnedCaches();
      if (mounted) {
        setState(() {});
        await showAdaptiveNotice(
          context,
          'Local data deleted',
          'Your classes and history are empty. Exported files were not deleted.',
        );
      }
    } on Object catch (error) {
      if (mounted) await showAdaptiveNotice(context, 'Delete failed', '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = repository;
    final history = repo?.history() ?? const <DaySummary>[];
    return ListView(
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
        const SizedBox(height: 24),
        const Text(
          'Your data',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Exports are saved only where you choose. Backups contain first names/aliases, settings and aggregate history; keep them private.',
        ),
        const SizedBox(height: 12),
        if (repo != null) ...[
          AdaptiveButton(
            key: const Key('export-rosters'),
            label: 'Export classes (CSV)',
            onPressed: () => _export(
              name: 'class-bell-classes.csv',
              content: rosterCsv(repo.load().rosters),
              label: 'Classes CSV',
            ),
          ),
          AdaptiveButton(
            key: const Key('export-history'),
            label: 'Export history (CSV)',
            onPressed: () => _export(
              name: 'class-bell-history.csv',
              content: historyCsv(repo.history()),
              label: 'History CSV',
            ),
          ),
          AdaptiveButton(
            key: const Key('export-backup'),
            label: 'Save full backup (JSON)',
            onPressed: () {
              widget.session.flushForBackup();
              _export(
                name: 'class-bell-backup.json',
                content: backupJson(repo.load(), repo.history()),
                label: 'Full backup',
              );
            },
          ),
          AdaptiveButton(
            key: const Key('import-backup'),
            label: 'Restore backup (JSON)',
            onPressed: _restore,
          ),
          AdaptiveButton(
            key: const Key('delete-all'),
            label: 'Delete all local data',
            onPressed: _deleteAll,
          ),
        ],
      ],
    );
  }
}

Future<void> showHistory(BuildContext context, ToolSession session) {
  final page = HistoryPage(session: session);
  switch (bellPlatform(context)) {
    case BellPlatform.windows:
      return Navigator.of(context).push<void>(
        PageRouteBuilder(
          pageBuilder: (ctx, _, _) => AdaptiveScaffold(
            title: 'History & data',
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
              middle: Text('History & data'),
            ),
            child: SafeArea(child: page),
          ),
        ),
      );
    case BellPlatform.android:
      return Navigator.of(context).push<void>(
        material.MaterialPageRoute(
          builder: (_) => material.Scaffold(
            appBar: material.AppBar(title: const Text('History & data')),
            body: page,
          ),
        ),
      );
  }
}
