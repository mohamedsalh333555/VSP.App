import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_design_tokens.dart';

/// Reusable social login/signup button with accessible Material interaction.
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
    final borderRadius = BorderRadius.circular(VSPDSRadius.button);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Material(
        color: VSPDSSemanticColors.surface,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          child: CustomPaint(
            painter: GradientBorderPainter(
              strokeWidth: VSPDSBorders.fieldFocus,
              radius: VSPDSRadius.button,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  VSPDSColors.white.withValues(alpha: 0.30),
                  VSPDSColors.transparent,
                  VSPDSColors.white.withValues(alpha: 0.30),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: height ?? VSPDSizes.buttonHeight,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: VSPDSSpacing.inputHorizontal,
                  ),
                  child: iconWidget,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter for gradient borders on buttons and cards.
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
