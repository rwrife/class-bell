import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../domain/roster.dart';
import '../repository/bell_repository.dart';

/// Formats one CSV field: quoting only when required, so a spreadsheet or a
/// text editor can read the export without the app and without guessing.
String csvField(String value) {
  if (value.contains('"') ||
      value.contains(',') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String csvRow(List<String> fields) => fields.map(csvField).join(',');

/// CSV roster export: one row per student, first names/aliases only.
/// Columns are fixed and documented; nothing else about a child is stored.
String rosterCsv(List<Roster> rosters) {
  final buffer = StringBuffer('class,name,initials,group,excluded\n');
  for (final roster in rosters) {
    for (final student in roster.students) {
      buffer.writeln(
        csvRow([
          roster.name,
          student.displayName,
          student.initials ?? '',
          student.group ?? '',
          student.isExcluded ? 'yes' : 'no',
        ]),
      );
    }
  }
  return buffer.toString();
}

/// CSV history export: aggregate day totals only (no sessions, no names).
String historyCsv(List<DaySummary> history) {
  final buffer = StringBuffer('day,praise_points,focus_seconds\n');
  for (final day in history) {
    buffer.writeln(
      csvRow([day.day, '${day.praisePoints}', '${day.focusSeconds}']),
    );
  }
  return buffer.toString();
}

/// Backup document: the whole local database in one human-readable file.
/// `format` + `schemaVersion` exist so a restore can refuse a foreign or
/// newer file instead of silently writing nonsense into the classroom DB.
/// No timestamps, no device info, no hidden metadata.
Map<String, dynamic> backupDocument(
  BellSnapshot snapshot,
  List<DaySummary> history,
) => {
  'format': 'class-bell-backup',
  'schemaVersion': 2,
  'rosters': snapshot.rosters.map((r) => r.toJson()).toList(),
  'selectedRosterId': snapshot.selectedRosterId,
  'settings': {
    'presetMinutes': snapshot.presetMinutes,
    'goal': snapshot.goal,
    'quietSound': snapshot.quietSound,
    'unlockComboIndex': snapshot.unlockComboIndex,
  },
  'praiseByRoster': snapshot.praiseByRoster,
  'history': history.map((day) => day.toJson()).toList(),
};

String backupJson(BellSnapshot snapshot, List<DaySummary> history) =>
    '${const JsonEncoder.withIndent('  ').convert(backupDocument(snapshot, history))}\n';

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// Opaque restore payload: full snapshot plus the aggregate day totals that
/// live in `day_totals` (they are not part of [BellSnapshot]).
class BackupData {
  const BackupData(this.snapshot, this.history);

  final BellSnapshot snapshot;
  final List<DaySummary> history;
}

/// Throws [BackupFormatException] with a teacher-readable reason when the file
/// is not a Class Bell backup this version can restore.
BackupData parseBackup(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (error) {
    throw BackupFormatException('Not a readable file: ${error.message}');
  }
  if (decoded is! Map<String, dynamic>) {
    throw BackupFormatException('Not a Class Bell backup file.');
  }
  if (decoded['format'] != 'class-bell-backup') {
    throw BackupFormatException('Not a Class Bell backup file.');
  }
  final schema = decoded['schemaVersion'];
  if (schema is! int) {
    throw BackupFormatException('The backup has no readable schema version.');
  }
  if (schema != 2) {
    throw BackupFormatException(
      schema > 2
          ? 'The backup comes from a newer version of Class Bell.'
          : 'This backup uses an unsupported schema version.',
    );
  }
  try {
    return _parseValidatedBackup(decoded);
  } on BackupFormatException {
    rethrow;
  } on Object {
    throw const BackupFormatException(
      'Backup fields are missing or unreadable.',
    );
  }
}

BackupData _parseValidatedBackup(Map<String, dynamic> decoded) {
  final settings = decoded['settings'] as Map<String, dynamic>;
  final rosters = (decoded['rosters'] as List<dynamic>).map((entry) {
    if (entry is! Map<String, dynamic>) {
      throw const BackupFormatException('A class entry is not readable.');
    }
    try {
      return Roster.fromJson(entry);
    } on Object catch (error) {
      throw BackupFormatException('A class entry is not readable ($error).');
    }
  }).toList();
  final rawPraise = decoded['praiseByRoster'] as Map<String, dynamic>;
  final history = (decoded['history'] as List<dynamic>).map((row) {
    final data = row as Map<String, dynamic>;
    final day = data['day'] as String;
    final points = data['praisePoints'] as int;
    final seconds = data['focusSeconds'] as int;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) || seconds < 0) {
      throw const BackupFormatException('Day history is not readable.');
    }
    return DaySummary(day, points, seconds);
  }).toList();
  if (history.map((day) => day.day).toSet().length != history.length) {
    throw const BackupFormatException('Duplicate days in history.');
  }
  final praise = <String, Map<String, dynamic>>{};
  rawPraise.forEach((key, value) {
    if (value is! Map<String, dynamic>) {
      throw BackupFormatException('Saved praise for "$key" is not readable.');
    }
    praise[key] = value;
  });
  final selectedId = decoded['selectedRosterId'] as String;
  final minutes = settings['presetMinutes'] as int;
  final goal = settings['goal'] as int;
  final combo = settings['unlockComboIndex'] as int;
  if ((selectedId.isNotEmpty && !rosters.any((r) => r.id == selectedId)) ||
      rosters.map((r) => r.id).toSet().length != rosters.length ||
      minutes < 1 ||
      minutes > 120 ||
      goal < 1 ||
      goal > 9999 ||
      combo < 0 ||
      combo > 2) {
    throw const BackupFormatException(
      'Backup settings or classes are invalid.',
    );
  }
  return BackupData(
    BellSnapshot(
      rosters: rosters,
      selectedRosterId: selectedId,
      presetMinutes: minutes,
      goal: goal,
      quietSound: settings['quietSound'] as bool,
      unlockComboIndex: combo,
      praiseByRoster: praise,
    ),
    history,
  );
}

/// Result of a user-initiated export: what was written and where the OS put it.
class ExportOutcome {
  const ExportOutcome({required this.succeeded, this.savedPath});

  final bool succeeded;
  final String? savedPath;
}

/// Save/export/restore plumbing. Kept as a thin seam over `file_picker` so the
/// whole round-trip can be tested with an injected fake while production wires
/// the native per-OS dialog.
abstract interface class BackupServices {
  /// Writes CSV/JSON through the native save dialog. Returns
  /// `ExportOutcome(succeeded: false)` when the user cancels.
  Future<ExportOutcome> saveDocument({
    required String fileName,
    required String content,
    required String label,
  });

  /// Reads a user-chosen file as UTF-8 text; `null` when the picker is
  /// cancelled or the file cannot be read.
  Future<String?> openDocument();
}

class FilePickerBackupServices implements BackupServices {
  const FilePickerBackupServices();

  @override
  Future<ExportOutcome> saveDocument({
    required String fileName,
    required String content,
    required String label,
  }) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save $label',
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
    if (path == null) return const ExportOutcome(succeeded: false);
    // On Android/iOS the plugin writes the bytes it was given; on desktop the
    // dialog only returns the chosen path, so the app writes the file itself.
    if (!Platform.isAndroid && !Platform.isIOS) {
      try {
        await File(path).writeAsString(content, flush: true);
      } on Object {
        return ExportOutcome(succeeded: false, savedPath: path);
      }
    }
    return ExportOutcome(succeeded: true, savedPath: path);
  }

  @override
  Future<String?> openDocument() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Open Class Bell backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    final bytes = picked.bytes ?? await File(picked.path!).readAsBytes();
    return utf8.decode(bytes);
  }
}

/// Files Class Bell creates for itself and may delete again. The file picker
/// keeps temporary copies of picked files inside the app sandbox. Exports the
/// user saved through the save dialog live outside the app and are never
/// touched by delete-all.
///
/// `clearTemporaryFiles` is implemented by the plugin's mobile implementation
/// only; desktop has no app-owned picker cache to clear, so a platform that
/// has not implemented it is treated as "nothing to clear".
Future<void> clearAppOwnedCaches() async {
  try {
    await FilePicker.platform.clearTemporaryFiles();
  } on UnimplementedError {
    // No app-owned picker cache exists on this platform.
  }
}
