import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../domain/roster.dart';
import '../state/roster_store.dart';
import 'adaptive.dart';

/// Keys used by tests and accessibility.
class RosterKeys {
  static const rosterList = Key('roster-list');
  static const emptyState = Key('roster-empty-state');
  static const addClass = Key('add-class');
  static const switchClass = Key('switch-class');
  static const classOptions = Key('class-options');
  static const addStudent = Key('add-student');
  static const nameField = Key('field-name');
  static const initialsField = Key('field-initials');
  static const groupField = Key('field-group');
  static const classNameField = Key('field-class-name');
  static const submit = Key('dialog-submit');
}

class RosterPage extends StatefulWidget {
  const RosterPage({required this.store, super.key});

  final RosterStore store;

  @override
  State<RosterPage> createState() => _RosterPageState();
}

class _RosterPageState extends State<RosterPage> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _addClass() async {
    final name = await showAdaptivePrompt(
      context: context,
      title: 'New class',
      submitLabel: 'Create',
      label: 'Class name',
      fieldKey: RosterKeys.classNameField,
    );
    if (name == null || name.trim().isEmpty) return;
    final error = RosterStore.validateRosterName(name);
    if (error != null) {
      if (!mounted) return;
      await showAdaptiveNotice(context, 'Cannot create class', error);
      return;
    }
    widget.store.createRoster(name);
  }

  Future<void> _renameClass(Roster roster) async {
    final name = await showAdaptivePrompt(
      context: context,
      title: 'Rename class',
      submitLabel: 'Save',
      label: 'Class name',
      initialText: roster.name,
    );
    if (name == null || name.trim().isEmpty) return;
    final error = RosterStore.validateRosterName(name);
    if (error != null) {
      if (!mounted) return;
      await showAdaptiveNotice(context, 'Cannot rename', error);
      return;
    }
    widget.store.renameRoster(roster.id, name);
  }

  Future<void> _deleteClass(Roster roster) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (_) => AdaptiveDialog(
        title: 'Delete ${roster.name}?',
        content: Text(
          'Removes the class and its ${roster.students.length} names. This cannot be undone.',
        ),
        cancel: 'Keep class',
        confirm: 'Delete class',
        onCancel: () => Navigator.of(context).pop(false),
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );
    if (confirmed == true) widget.store.deleteRoster(roster.id);
  }

  Future<void> _editStudent({Roster? roster, Student? student}) async {
    final targetRoster = roster ?? widget.store.selectedRoster;
    if (targetRoster == null) return;
    final result = await showAdaptiveDialog<_StudentDraft>(
      context: context,
      builder: (_) => _StudentForm(
        title: student == null ? 'Add name' : 'Edit ${student.displayName}',
        submitLabel: student == null ? 'Add' : 'Save',
        initialName: student?.displayName,
        initialInitials: student?.initials,
        initialGroup: student?.group ?? targetRoster.groups.firstOrNull,
      ),
    );
    if (result == null) return;
    if (student == null) {
      widget.store.addStudent(
        rosterId: targetRoster.id,
        displayName: result.name,
        initials: result.initials,
        group: result.group,
      );
    } else {
      widget.store.updateStudent(
        rosterId: targetRoster.id,
        student: Student(
          id: student.id,
          displayName: result.name,
          initials: result.initials,
          group: result.group,
          isExcluded: student.isExcluded,
        ),
      );
    }
  }

  Future<void> _removeStudent(Roster roster, Student student) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (_) => AdaptiveDialog(
        title: 'Remove ${student.displayName}?',
        content: const Text(
          'They will no longer appear in this class or random draws.',
        ),
        cancel: 'Keep',
        confirm: 'Remove',
        onCancel: () => Navigator.of(context).pop(false),
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );
    if (confirmed == true) {
      widget.store.removeStudent(rosterId: roster.id, studentId: student.id);
    }
  }

  Widget _classList(Roster? selected) {
    return Semantics(
      container: true,
      label: 'Classes',
      child: ListView(
        key: const Key('class-list'),
        children: [
          for (final roster in widget.store.rosters)
            AdaptiveSelectableTile(
              key: Key('class-${roster.id}'),
              label: '${roster.name}, ${roster.students.length} names',
              title: roster.name,
              subtitle: '${roster.students.length} names',
              selected: roster.id == selected?.id,
              onTap: () => widget.store.selectRoster(roster.id),
              trailing: AdaptiveIconButton(
                iconDescription: 'Class options',
                onPressed: () => _classMenu(roster),
                icon: AdaptiveIcon.more,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _chooseClass() async {
    final id = await showAdaptiveSheet<String>(
      context: context,
      title: 'Switch class',
      options: [for (final r in widget.store.rosters) (r.id, r.name)],
    );
    if (id != null) widget.store.selectRoster(id);
  }

  Future<void> _classMenu(Roster roster) async {
    final action = await showAdaptiveSheet<String>(
      context: context,
      title: roster.name,
      options: const [('rename', 'Rename class'), ('delete', 'Delete class')],
    );
    if (!mounted) return;
    if (action == 'rename') await _renameClass(roster);
    if (action == 'delete') await _deleteClass(roster);
  }

  Widget _students(Roster roster) {
    if (roster.students.isEmpty) {
      return const Center(
        key: RosterKeys.emptyState,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No names yet.\nAdd first names or aliases — this app stores no last names, emails, or photos.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      key: RosterKeys.rosterList,
      children: [
        for (final student in roster.students)
          AdaptiveTile(
            key: Key('student-${student.id}'),
            semanticLabel:
                '${student.displayName}${student.group == null ? '' : ', ${student.group}'}'
                '${student.isExcluded ? ', skipped in draws' : ''}',
            title:
                student.displayName + (student.isExcluded ? ' · skipped' : ''),
            subtitle: [
              if (student.initials != null) student.initials!,
              if (student.group != null) student.group!,
            ].join(' · '),
            leading: AdaptiveAvatar(
              initials:
                  student.initials ?? student.displayName.characters.first,
            ),
            onTap: () => _editStudent(roster: roster, student: student),
            trailing: AdaptiveIconButton(
              iconDescription: 'Remove ${student.displayName}',
              onPressed: () => _removeStudent(roster, student),
              icon: AdaptiveIcon.delete,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final selected = widget.store.selectedRoster;
        final body = widget.store.rosters.isEmpty
            ? Center(
                key: RosterKeys.emptyState,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'No classes yet',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create a class, then add first names or aliases.',
                    ),
                    const SizedBox(height: 16),
                    AdaptiveButton(
                      key: RosterKeys.addClass,
                      label: 'Create first class',
                      onPressed: _addClass,
                    ),
                  ],
                ),
              )
            : Row(
                children: [
                  if (width >= 700) ...[
                    SizedBox(width: 240, child: _classList(selected)),
                    const material.VerticalDivider(width: 1),
                  ],
                  Expanded(
                    child: Column(
                      children: [
                        AdaptiveCommandBar(
                          label: selected?.name ?? 'Class',
                          items: [
                            if (width < 700 && selected != null)
                              AdaptiveCommandItem(
                                key: RosterKeys.switchClass,
                                description: 'Switch',
                                icon: AdaptiveIcon.classes,
                                onPressed: _chooseClass,
                              ),
                            AdaptiveCommandItem(
                              key: RosterKeys.addStudent,
                              description: 'Add name',
                              icon: AdaptiveIcon.add,
                              onPressed: () => _editStudent(),
                            ),
                            AdaptiveCommandItem(
                              key: RosterKeys.addClass,
                              description: 'New class',
                              icon: AdaptiveIcon.addClass,
                              onPressed: _addClass,
                            ),
                            if (width < 700 && selected != null)
                              AdaptiveCommandItem(
                                key: RosterKeys.classOptions,
                                description: 'Class options',
                                icon: AdaptiveIcon.more,
                                onPressed: () => _classMenu(selected),
                              ),
                          ],
                        ),
                        Expanded(
                          child: selected == null
                              ? _classList(selected)
                              : _students(selected),
                        ),
                      ],
                    ),
                  ),
                ],
              );
        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final ctrl = HardwareKeyboard.instance.isControlPressed;
            if (ctrl && event.logicalKey == LogicalKeyboardKey.keyN) {
              _addClass();
              return KeyEventResult.handled;
            }
            if (ctrl && event.logicalKey == LogicalKeyboardKey.keyA) {
              _editStudent();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: body,
        );
      },
    );
  }
}

class _StudentDraft {
  const _StudentDraft(this.name, this.initials, this.group);

  final String name;
  final String? initials;
  final String? group;
}

class _StudentForm extends StatefulWidget {
  const _StudentForm({
    required this.title,
    required this.submitLabel,
    this.initialName,
    this.initialInitials,
    this.initialGroup,
  });

  final String title;
  final String submitLabel;
  final String? initialName;
  final String? initialInitials;
  final String? initialGroup;

  @override
  State<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<_StudentForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _initials = TextEditingController(
    text: widget.initialInitials,
  );
  late final TextEditingController _group = TextEditingController(
    text: widget.initialGroup,
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _initials.dispose();
    _group.dispose();
    super.dispose();
  }

  void _submit() {
    final errors = [
      RosterStore.validateStudentDisplayName(_name.text),
      RosterStore.validateInitials(_initials.text),
      RosterStore.validateGroup(_group.text),
    ].nonNulls.toList();
    if (errors.isNotEmpty) {
      setState(() => _error = errors.first);
      return;
    }
    Navigator.of(context).pop(
      _StudentDraft(
        _name.text.trim(),
        _initials.text.trim().isEmpty ? null : _initials.text.trim(),
        _group.text.trim().isEmpty ? null : _group.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveDialog(
      title: widget.title,
      cancel: 'Cancel',
      confirm: widget.submitLabel,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: _submit,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdaptiveTextField(
            key: RosterKeys.nameField,
            label: 'First name or alias',
            controller: _name,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          AdaptiveTextField(
            key: RosterKeys.initialsField,
            label: 'Initials (optional)',
            controller: _initials,
          ),
          const SizedBox(height: 12),
          AdaptiveTextField(
            key: RosterKeys.groupField,
            label: 'Group (optional)',
            controller: _group,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                label: 'Error: $_error',
                child: Text(_error!, key: const Key('form-error')),
              ),
            ),
        ],
      ),
    );
  }
}
