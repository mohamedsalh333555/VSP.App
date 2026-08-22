import 'dart:ui';
import 'package:flutter/material.dart';
import '../tokens/vsp_tokens.dart';

class VSPCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Border? border;
  final double? width;
  final double? height;
  final double? borderRadius;
  final bool isGlass;

  const VSPCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.border,
    this.width,
    this.height,
    this.borderRadius,
    this.isGlass = false, // 🛑 FIX: جعل الافتراضي معتم صلب وليس شفافاً لمنع تسريب خلفية البوب اب
  });

  @override
  Widget build(BuildContext context) {
    final double r = borderRadius ?? VSPRadius.card;
    final double sigma = isGlass ? VSPColors.glassBlurSigma : 0.0;

    if (!isGlass) {
      // 🛡️ كارت معتم صلب 100% بدون أي Blur أو الشفافية
      return Container(
        width: width,
        height: height,
        margin: margin,
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? VSPColors.surface, // Solid Opaque Zinc 900
          borderRadius: BorderRadius.circular(r),
          border: border ?? Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
    }

    // 🔮 كارت زجاجي شفاف (عند طلبه صراحةً بـ isGlass: true)
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color ?? VSPColors.glassSurface,
              borderRadius: BorderRadius.circular(r),
              border: border ?? Border.all(
                color: VSPColors.glassBorder,
                width: 1,
              ),
              boxShadow: [
                const BoxShadow(
                  color: VSPColors.glassGlow,
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}