import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

/// ايقونة الذكاء الاصطناعي المستوحاة من Google Gemini Sparkle
/// ترسم النجمتين المنحنيتين بتدرج هوية VSP المتطابق مع إطار Pro
class GeminiAIIcon extends StatelessWidget {
  final double size;
  final bool useGradient;
  final Color? color;
  final List<Color>? customGradientColors;

  const GeminiAIIcon({
    super.key,
    this.size = 20.0,
    this.useGradient = true,
    this.color,
    this.customGradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _GeminiSparklePainter(
          useGradient: useGradient,
          solidColor: color ?? VSPColors.accent,
          gradientColors: customGradientColors ??
              const [
                VSPColors.accent,
                Color(0xFF84CC16),
                Color(0xFF22C55E),
              ],
        ),
      ),
    );
  }
}

class _GeminiSparklePainter extends CustomPainter {
  final bool useGradient;
  final Color solidColor;
  final List<Color> gradientColors;

  _GeminiSparklePainter({
    required this.useGradient,
    required this.solidColor,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    final paint = Paint()..style = PaintingStyle.fill;

    if (useGradient) {
      // تدرج هوية VSP الخضراء المتطابق تماماً مع إطار Pro لصورة اللاعب والمالك
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
        stops: gradientColors.length == 3 ? const [0.0, 0.5, 1.0] : null,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    } else {
      paint.color = solidColor;
    }

    // 1. النجمة الكبرى الرئيسية (Main 4-pointed sparkle)
    // المركز: (9.5 * scale, 9.5 * scale) بنصف قطر تقريبي 8.0
    final pathMain = Path();
    final double cx1 = 10.0 * scale;
    final double cy1 = 10.0 * scale;
    final double r1 = 8.8 * scale;
    const double curvePull1 = 0.55;

    pathMain.moveTo(cx1, cy1 - r1);
    // القوس نحو اليمين
    pathMain.cubicTo(
      cx1, cy1 - r1 * (1 - curvePull1),
      cx1 + r1 * (1 - curvePull1), cy1,
      cx1 + r1, cy1,
    );
    // القوس نحو الأسفل
    pathMain.cubicTo(
      cx1 + r1 * (1 - curvePull1), cy1,
      cx1, cy1 + r1 * (1 - curvePull1),
      cx1, cy1 + r1,
    );
    // القوس نحو اليسار
    pathMain.cubicTo(
      cx1, cy1 + r1 * (1 - curvePull1),
      cx1 - r1 * (1 - curvePull1), cy1,
      cx1 - r1, cy1,
    );
    // القوس نحو الأعلى
    pathMain.cubicTo(
      cx1 - r1 * (1 - curvePull1), cy1,
      cx1, cy1 - r1 * (1 - curvePull1),
      cx1, cy1 - r1,
    );
    pathMain.close();

    canvas.drawPath(pathMain, paint);

    // 2. النجمة الصغرى في الركن السفلي الأيمن (Secondary smaller sparkle)
    // المركز: (19.0 * scale, 18.0 * scale) بنصف قطر تقريبي 4.2
    final pathSmall = Path();
    final double cx2 = 19.0 * scale;
    final double cy2 = 18.0 * scale;
    final double r2 = 4.4 * scale;
    const double curvePull2 = 0.55;

    pathSmall.moveTo(cx2, cy2 - r2);
    // اليمين
    pathSmall.cubicTo(
      cx2, cy2 - r2 * (1 - curvePull2),
      cx2 + r2 * (1 - curvePull2), cy2,
      cx2 + r2, cy2,
    );
    // الأسفل
    pathSmall.cubicTo(
      cx2 + r2 * (1 - curvePull2), cy2,
      cx2, cy2 + r2 * (1 - curvePull2),
      cx2, cy2 + r2,
    );
    // اليسار
    pathSmall.cubicTo(
      cx2, cy2 + r2 * (1 - curvePull2),
      cx2 - r2 * (1 - curvePull2), cy2,
      cx2 - r2, cy2,
    );
    // الأعلى
    pathSmall.cubicTo(
      cx2 - r2 * (1 - curvePull2), cy2,
      cx2, cy2 - r2 * (1 - curvePull2),
      cx2, cy2 - r2,
    );
    pathSmall.close();

    canvas.drawPath(pathSmall, paint);
  }

  @override
  bool shouldRepaint(covariant _GeminiSparklePainter oldDelegate) {
    return oldDelegate.useGradient != useGradient ||
        oldDelegate.solidColor != solidColor ||
        oldDelegate.gradientColors != gradientColors;
  }
}
