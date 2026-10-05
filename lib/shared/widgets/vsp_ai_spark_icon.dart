import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_design_tokens.dart';

/// VSP Copilot identity icon: two four-point spark stars with intentionally
/// different sizes. This restores the existing VSP visual language without
/// introducing a new color or icon family.
///
/// The geometry is a component rule, not a screen-local decoration.
class VSPAiSparkIcon extends StatelessWidget {
  final double size;
  final Color color;

  const VSPAiSparkIcon({
    super.key,
    this.size = VSPDSizes.aiIcon,
    this.color = VSPDSSemanticColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    final large = size * (VSPDSizes.aiIconLarge / VSPDSizes.aiIcon);
    final small = size * (VSPDSizes.aiIconSmall / VSPDSizes.aiIcon);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: _Spark(
              size: large,
              color: color,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: _Spark(
              size: small,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Spark extends StatelessWidget {
  final double size;
  final Color color;

  const _Spark({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _FourPointSparkPainter(color),
    );
  }
}

class _FourPointSparkPainter extends CustomPainter {
  final Color color;

  const _FourPointSparkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outer = size.width / 2;
    final inner = outer * 0.22;

    final path = Path()
      ..moveTo(cx, 0)
      ..quadraticBezierTo(cx + inner, cy - inner, size.width, cy)
      ..quadraticBezierTo(cx + inner, cy + inner, cx, size.height)
      ..quadraticBezierTo(cx - inner, cy + inner, 0, cy)
      ..quadraticBezierTo(cx - inner, cy - inner, cx, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FourPointSparkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
