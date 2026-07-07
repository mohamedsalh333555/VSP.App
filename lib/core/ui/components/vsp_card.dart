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
    this.isGlass = false, // Default to false for solid premium readability
  });

  @override
  Widget build(BuildContext context) {
    final double r = borderRadius ?? VSPRadius.lg;
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: isGlass ? 16 : 0, sigmaY: isGlass ? 16 : 0),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color ?? (isGlass ? VSPColors.glassSurface : VSPColors.surface),
              borderRadius: BorderRadius.circular(r),
              border: border ?? Border.all(
                color: isGlass ? VSPColors.accent.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05), // Subtle white stroke
                width: 1,
              ),
              boxShadow: isGlass ? [
                BoxShadow(
                  color: VSPColors.accent.withValues(alpha: 0.04),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ] : [],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}