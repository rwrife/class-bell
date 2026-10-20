import 'dart:math';

import 'package:flutter/widgets.dart';

/// Platform-neutral countdown ring drawn with CustomPaint.
///
/// Chrome-free on purpose: the ring is content, not native chrome, so it is
/// identical on Fluent, Material, and Cupertino.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    required this.progress,
    required this.child,
    this.dimmed = false,
    super.key,
  });

  /// Fraction of the ring that is still remaining (1 = full).
  final double progress;
  final Widget child;
  final bool dimmed;

  static const Color _track = Color(0xFF315AA4);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RingPainter(
        progress: progress.clamp(0.0, 1.0),
        color: dimmed ? _track.withValues(alpha: 0.35) : _track,
        trackColor: dimmed
            ? _track.withValues(alpha: 0.06)
            : _track.withValues(alpha: 0.15),
      ),
      child: Center(child: child),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = min(size.width, size.height) * 0.06;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawArc(rect, 0, pi * 2, false, track);
    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    // Start at 12 o'clock and sweep clockwise as time remains.
    canvas.drawArc(rect, -pi / 2, pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Formats a duration as `m:ss` for projector-scale countdowns.
String formatCountdown(Duration d) {
  final total = d.isNegative ? Duration.zero : d;
  return '${total.inMinutes}:${(total.inSeconds % 60).toString().padLeft(2, '0')}';
}

/// Calm gradient backdrop for the quiet-signal full-screen cue.
class QuietBackdrop extends StatelessWidget {
  const QuietBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('quiet-backdrop'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF16243B), Color(0xFF2C4A72)],
        ),
      ),
      child: child,
    );
  }
}
