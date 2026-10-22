import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';

import '../domain/timer.dart';
import '../state/tool_session.dart';
import 'adaptive.dart';
import 'history_page.dart';
import 'tools/widgets.dart';

/// Compact settings row every tool screen exposes when not projecting:
/// enter projector (locks) and cycle the teacher-unlock combo.
class ProjectorControls extends StatelessWidget {
  const ProjectorControls({required this.session, super.key});

  final ToolSession session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => session.projector
        ? const SizedBox.shrink()
        : Padding(
            // CupertinoSliverNavigationBar overlays start of SliverFillRemaining
            // in compact tabs; keep settings below its touch target.
            padding: EdgeInsets.fromLTRB(
              12,
              bellPlatform(context) == BellPlatform.ios ? 96 : 4,
              12,
              4,
            ),
            child: Wrap(
              spacing: 8,
              alignment: WrapAlignment.end,
              children: [
                AdaptiveButton(
                  key: const Key('projector-enter'),
                  label: 'Projector',
                  onPressed: session.enterProjector,
                ),
                AdaptiveButton(
                  key: const Key('unlock-combo'),
                  label: 'Unlock: ${session.unlockCombo.label}',
                  onPressed: session.cycleUnlockCombo,
                ),
              ],
            ),
          ),
  );
}

/// Shared tool content; platform chrome comes only from Adaptive widgets.
class ToolPage extends StatelessWidget {
  const ToolPage({required this.index, required this.session, super.key});

  final int index;
  final ToolSession session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => Column(
      children: [
        ProjectorControls(session: session),
        Expanded(
          child: switch (index) {
            1 => _TimerPage(session: session),
            2 => _PickerPage(session: session),
            3 => _PraisePage(session: session),
            4 => _QuietPage(session: session),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    ),
  );
}

class _ToolAction extends StatelessWidget {
  const _ToolAction({
    required this.label,
    required this.onPressed,
    this.keyName,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? keyName;

  @override
  Widget build(BuildContext context) => AdaptiveButton(
    key: keyName == null ? null : Key(keyName!),
    label: label,
    onPressed: onPressed,
  );
}

class _TimerPage extends StatelessWidget {
  const _TimerPage({required this.session});

  final ToolSession session;

  @override
  Widget build(BuildContext context) {
    final snap = session.snapshot;
    final remaining = snap.phase == TimerPhase.idle
        ? Duration(minutes: session.presetMinutes)
        : snap.remaining;
    final big = session.projector;
    return Container(
      color: session.dim ? const Color(0xFF111827) : null,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (!session.locked)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final preset in [1, 5, 10, 12, 20, 30])
                            _ToolAction(
                              keyName: 'preset-$preset',
                              label: '$preset min',
                              onPressed: () => session.setPreset(preset),
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: min(
                        bounds.maxWidth - 32,
                        big
                            ? 410
                            : bounds.maxWidth < 500
                            ? 195
                            : 290,
                      ),
                      height: min(
                        bounds.maxWidth - 32,
                        big
                            ? 410
                            : bounds.maxWidth < 500
                            ? 195
                            : 290,
                      ),
                      child: CountdownRing(
                        progress: snap.phase == TimerPhase.idle
                            ? 1
                            : 1 - snap.progress,
                        dimmed: session.dim,
                        child: Semantics(
                          liveRegion: snap.phase == TimerPhase.finished,
                          label: '${formatCountdown(remaining)} remaining',
                          child: Text(
                            formatCountdown(remaining),
                            key: const Key('countdown'),
                            style: TextStyle(
                              fontSize: big ? 82 : 64,
                              fontWeight: FontWeight.bold,
                              color: session.dim
                                  ? const Color(0xFFE5E7EB)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        _ToolAction(
                          keyName: 'timer-toggle',
                          label: switch (snap.phase) {
                            TimerPhase.running => 'Pause',
                            TimerPhase.paused => 'Resume',
                            _ => 'Start',
                          },
                          onPressed: session.toggleTimer,
                        ),
                        _ToolAction(
                          keyName: 'timer-skip',
                          label: 'Skip',
                          onPressed:
                              snap.phase == TimerPhase.running ||
                                  snap.phase == TimerPhase.paused
                              ? session.skip
                              : null,
                        ),
                        _ToolAction(
                          keyName: 'timer-dim',
                          label: session.dim ? 'Brighten' : 'Dim',
                          onPressed: session.toggleDim,
                        ),
                      ],
                    ),
                    if (session.audioError != null) Text(session.audioError!),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerPage extends StatelessWidget {
  const _PickerPage({required this.session});

  final ToolSession session;

  @override
  Widget build(BuildContext context) {
    final roster = session.store.selectedRoster;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, bounds) => SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text(
                      roster?.name ?? 'No class selected',
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: session.projector ? 220 : 160,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 350),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              session.selectedName ?? 'Ready to pick',
                              key: ValueKey(session.selectedName ?? 'none'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: session.projector ? 76 : 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _ToolAction(
                      keyName: 'picker-next',
                      label: 'Pick next name',
                      onPressed: roster == null ? null : session.draw,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      session.drawNotice.isEmpty
                          ? 'No repeats until everyone has a turn'
                          : session.drawNotice,
                      key: const Key('rotation-status'),
                      textAlign: TextAlign.center,
                    ),
                    if (!session.locked && roster != null) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Include in draw',
                        style: TextStyle(fontSize: 20),
                      ),
                      for (final student in roster.students)
                        _ExclusionRow(
                          name: student.displayName,
                          excluded: student.isExcluded,
                          onChanged: () => session.toggleExclusion(student.id),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExclusionRow extends StatelessWidget {
  const _ExclusionRow({
    required this.name,
    required this.excluded,
    required this.onChanged,
  });

  final String name;
  final bool excluded;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$name, ${excluded ? 'excluded' : 'included'} in draw',
    child: switch (bellPlatform(context)) {
      BellPlatform.windows => fluent.ToggleSwitch(
        checked: !excluded,
        content: Text(name),
        onChanged: (_) => onChanged(),
      ),
      BellPlatform.ios => cupertino.CupertinoListTile(
        title: Text(name),
        trailing: cupertino.CupertinoSwitch(
          value: !excluded,
          onChanged: (_) => onChanged(),
        ),
      ),
      BellPlatform.android => material.SwitchListTile(
        title: Text(name),
        value: !excluded,
        onChanged: (_) => onChanged(),
      ),
    },
  );
}

class _PraisePage extends StatelessWidget {
  const _PraisePage({required this.session});

  final ToolSession session;

  @override
  Widget build(BuildContext context) {
    final praise = session.praise;
    final big = session.projector;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Center(
            child: Text(
              '${praise.progress} / ${praise.goal}',
              key: const Key('praise-progress'),
              style: TextStyle(
                fontSize: big ? 70 : 50,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Center(
            child: Text(
              praise.goalReached ? 'Class goal reached!' : 'Toward class goal',
            ),
          ),
          const SizedBox(height: 16),
          // Settings row first: on phones the tallies can scroll, these
          // controls must stay reachable without hunting below the fold.
          if (!session.locked)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  _ToolAction(
                    keyName: 'praise-goal',
                    label: 'Set goal',
                    onPressed: () async {
                      final input = await showAdaptivePrompt(
                        context: context,
                        title: 'Class goal',
                        submitLabel: 'Set goal',
                        label: 'Points (1–9999)',
                        initialText: '${session.goal}',
                      );
                      if (input == null || !context.mounted) return;
                      final value = int.tryParse(input.trim());
                      if (value == null || value < 1 || value > 9999) {
                        await showAdaptiveNotice(
                          context,
                          'Invalid goal',
                          'Enter a number from 1 to 9999.',
                        );
                      } else {
                        session.setGoal(value);
                      }
                    },
                  ),
                  _ToolAction(
                    keyName: 'praise-history',
                    label: 'History',
                    onPressed: () {
                      final items =
                          session.store.repository?.history() ??
                          (session.repository?.history() ?? const []);
                      showHistory(context, items);
                    },
                  ),
                  _ToolAction(
                    keyName: 'praise-reset',
                    label: 'New session',
                    onPressed: () async {
                      final confirmed = await showAdaptiveDialog<bool>(
                        context: context,
                        builder: (ctx) => AdaptiveDialog(
                          title: 'Reset praise session?',
                          content: const Text(
                            'All current tallies will reset to zero.',
                          ),
                          cancel: 'Keep tallies',
                          confirm: 'Reset',
                          onCancel: () => Navigator.of(ctx).pop(false),
                          onConfirm: () => Navigator.of(ctx).pop(true),
                        ),
                      );
                      if (confirmed == true) session.resetPraise();
                    },
                  ),
                ],
              ),
            ),
          _PraiseRow(
            name: 'Whole class',
            points: praise.classPoints,
            big: big,
            onAdd: () => session.praisePoint(null),
            onRemove: () => session.praisePoint(null, subtract: true),
          ),
          for (final group in praise.groups)
            _PraiseRow(
              name: group,
              points: praise.groupPoints(group),
              big: big,
              onAdd: () => session.praisePoint(group),
              onRemove: () => session.praisePoint(group, subtract: true),
            ),
        ],
      ),
    );
  }
}

class _PraiseRow extends StatelessWidget {
  const _PraiseRow({
    required this.name,
    required this.points,
    required this.big,
    required this.onAdd,
    required this.onRemove,
  });

  final String name;
  final int points;
  final bool big;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Semantics(
      label: '$name, $points praise points',
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          SizedBox(
            width: big ? 280 : 170,
            child: Text(name, style: TextStyle(fontSize: big ? 30 : 22)),
          ),
          Text('$points', style: TextStyle(fontSize: big ? 40 : 28)),
          _ToolAction(
            keyName: 'praise-minus-$name',
            label: '− $name',
            onPressed: points > 0 ? onRemove : null,
          ),
          _ToolAction(
            keyName: 'praise-plus-$name',
            label: '+ $name',
            onPressed: onAdd,
          ),
        ],
      ),
    ),
  );
}

class _QuietPage extends StatelessWidget {
  const _QuietPage({required this.session});

  final ToolSession session;

  @override
  Widget build(BuildContext context) => QuietBackdrop(
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                cupertino.CupertinoIcons.bell_slash,
                size: 100,
                color: Color(0xFFD9E7F5),
              ),
              const SizedBox(height: 24),
              Text(
                'Quiet time',
                key: const Key('quiet-title'),
                style: TextStyle(
                  fontSize: session.projector ? 76 : 48,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Take a breath. Listen together.',
                style: TextStyle(fontSize: 22, color: Color(0xFFFFFFFF)),
              ),
              const SizedBox(height: 24),
              if (!session.locked)
                _ToolAction(
                  keyName: 'quiet-sound',
                  label: session.quietSound ? 'Sound on' : 'Sound off',
                  onPressed: session.toggleQuietSound,
                ),
              const SizedBox(height: 12),
              _ToolAction(
                keyName: 'quiet-cue',
                label:
                    'Show quiet cue${session.quietSound ? ' with sound' : ''}',
                onPressed: session.quietCue,
              ),
              if (session.audioError != null)
                Text(
                  session.audioError!,
                  style: const TextStyle(color: Color(0xFFFFFFFF)),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
