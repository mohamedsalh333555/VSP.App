import 'dart:math' as math;
import 'package:flutter/material.dart';

// ──────────────────────────────────────────────────────────────────────────
// RADIAL TICK GAUGE PAINTER (دائرة المؤشرات الشعاعية الدقيقة)
// ──────────────────────────────────────────────────────────────────────────
class RadialTickGaugePainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final int totalTicks;
  final double tickLength;
  final double strokeWidth;

  RadialTickGaugePainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.totalTicks,
    required this.tickLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (size.width / 2) - 2;
    final innerRadius = outerRadius - tickLength;
    const startAngle = -math.pi / 2; // 12 o'clock
    final angleStep = (2 * math.pi) / totalTicks;

    final activeTicksCount = (progress * totalTicks).round().clamp(progress > 0 ? 1 : 0, totalTicks);

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < totalTicks; i++) {
      final angle = startAngle + (i * angleStep);
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      final p1 = Offset(center.dx + innerRadius * cosA, center.dy + innerRadius * sinA);
      final p2 = Offset(center.dx + outerRadius * cosA, center.dy + outerRadius * sinA);

      final isTickActive = i < activeTicksCount;
      canvas.drawLine(p1, p2, isTickActive ? activePaint : inactivePaint);
    }
  }

  @override
  bool shouldRepaint(covariant RadialTickGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
