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
    this.isGlass = true, // Default to true for full Glassmorphism experience
  });

  @override
  Widget build(BuildContext context) {
    final double r = borderRadius ?? VSPRadius.lg;
    final double sigma = isGlass ? VSPColors.glassBlurSigma : 0.0;

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
              color: color ?? (isGlass ? VSPColors.glassSurface : VSPColors.surface),
              borderRadius: BorderRadius.circular(r),
              border: border ?? Border.all(
                color: isGlass ? VSPColors.glassBorder : Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isGlass ? VSPColors.glassGlow : Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
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