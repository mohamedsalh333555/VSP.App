import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

/// Reusable social login/signup button with gradient border
class SocialAuthButton extends StatelessWidget {
  final Widget iconWidget;
  final VoidCallback? onPressed;
  final double? height;

  const SocialAuthButton({
    super.key,
    required this.iconWidget,
    required this.onPressed,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: CustomPaint(
        painter: GradientBorderPainter(
          strokeWidth: 1.5,
          radius: VSPRadius.button,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.30),
              Colors.transparent,
              Colors.white.withValues(alpha: 0.30),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Container(
          width: double.infinity,
          height: height ?? VSPSize.buttonHeight,
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.button),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: iconWidget,
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter for gradient borders on buttons and cards
class GradientBorderPainter extends CustomPainter {
  final double strokeWidth;
  final double radius;
  final Gradient gradient;

  GradientBorderPainter({
    required this.strokeWidth,
    required this.radius,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius - strokeWidth / 2),
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant GradientBorderPainter oldDelegate) => false;
}
