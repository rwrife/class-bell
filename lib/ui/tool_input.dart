import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../state/tool_session.dart';

/// Keyboard layer for the shell and projector mode.
///
/// Shortcuts (README contract): space = timer start/pause, n = next pick,
/// = / + and - = whole-class praise points, 1-4 = switch tool, Escape = exit
/// projector (when unlocked). The teacher-lock combo works anywhere.
class ToolInput extends StatelessWidget {
  const ToolInput({
    required this.session,
    required this.onSelectTool,
    required this.child,
    super.key,
  });

  final ToolSession session;
  final ValueChanged<int> onSelectTool;
  final Widget child;

  static LogicalKeyboardKey _mainKey(UnlockCombo combo) =>
      switch (combo.keyName) {
        'KeyL' => LogicalKeyboardKey.keyL,
        'KeyK' => LogicalKeyboardKey.keyK,
        _ => LogicalKeyboardKey.f9,
      };

  bool _isUnlockCombo(KeyDownEvent event) {
    final hk = HardwareKeyboard.instance;
    if (event.logicalKey != _mainKey(session.unlockCombo)) return false;
    // Ctrl+Shift+K uses Shift; the other combos use Alt.
    return hk.isControlPressed &&
        (session.unlockCombo.keyName == 'KeyK'
            ? hk.isShiftPressed
            : hk.isAltPressed);
  }

  KeyEventResult _handle(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isUnlockCombo(event)) {
      session.unlock();
      return KeyEventResult.handled;
    }
    if (!session.projector) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      session.toggleTimer();
    } else if (key == LogicalKeyboardKey.keyN) {
      session.draw();
    } else if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.numpadAdd) {
      session.praisePoint(null);
    } else if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      session.praisePoint(null, subtract: true);
    } else if (key == LogicalKeyboardKey.escape) {
      session.leaveProjector();
    } else {
      final tool = switch (key) {
        LogicalKeyboardKey.digit1 => 1,
        LogicalKeyboardKey.digit2 => 2,
        LogicalKeyboardKey.digit3 => 3,
        LogicalKeyboardKey.digit4 => 4,
        _ => 0,
      };
      if (tool == 0) return KeyEventResult.ignored;
      onSelectTool(tool);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) =>
      Focus(canRequestFocus: false, onKeyEvent: _handle, child: child);
}

/// Corner chip shown in projector mode. Long-press (or the configured combo)
/// unlocks; students tapping it do nothing.
class LockChip extends StatelessWidget {
  const LockChip({required this.session, super.key});

  final ToolSession session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => Semantics(
      label: session.locked
          ? 'Teacher lock on. Long-press or press ${session.unlockCombo.label} to unlock'
          : 'Teacher lock off',
      child: GestureDetector(
        key: const Key('lock-chip'),
        onLongPress: session.unlock,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x66000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                session.locked
                    ? 'Locked · hold or ${session.unlockCombo.label}'
                    : 'Unlocked',
                style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
