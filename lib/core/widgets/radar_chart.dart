import 'dart:math';
import 'package:flutter/material.dart';
import '../ui/tokens/vsp_tokens.dart';

class VSPRadarChart extends StatelessWidget {
  final Map<String, double> values;
  final double size;
  final Color color;

  const VSPRadarChart({
    super.key,
    required this.values,
    this.size = 180,
    this.color = VSPColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: RadarChartPainter(
          values: values,
          color: color,
        ),
      ),
    );
  }
}

class RadarChartPainter extends CustomPainter {
  final Map<String, double> values;
  final Color color;

  RadarChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final axisCount = values.length;
    final angle = (2 * pi) / axisCount;

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw background circles/polygons
    for (var i = 1; i <= 4; i++) {
      final r = radius * (i / 4);
      final path = Path();
      for (var j = 0; j < axisCount; j++) {
        final x = center.dx + r * cos(j * angle - pi / 2);
        final y = center.dy + r * sin(j * angle - pi / 2);
        if (j == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, linePaint);
    }

    // Draw axis lines
    for (var j = 0; j < axisCount; j++) {
      final x = center.dx + radius * cos(j * angle - pi / 2);
      final y = center.dy + radius * sin(j * angle - pi / 2);
      canvas.drawLine(center, Offset(x, y), linePaint);
    }

    // Draw data path
    final dataPath = Path();
    final keys = values.keys.toList();
    for (var i = 0; i < axisCount; i++) {
      final val = (values[keys[i]] ?? 0) / 100;
      final r = radius * val;
      final x = center.dx + r * cos(i * angle - pi / 2);
      final y = center.dy + r * sin(i * angle - pi / 2);
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, borderPaint);

    // Draw labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (var i = 0; i < axisCount; i++) {
      final label = keys[i];
      final r = radius + 15;
      final x = center.dx + r * cos(i * angle - pi / 2);
      final y = center.dy + r * sin(i * angle - pi / 2);

      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
