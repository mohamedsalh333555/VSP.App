import 'dart:ui';
import 'package:flutter/material.dart';
import '../tokens/vsp_design_tokens.dart';

/// Canonical VSP surface/card primitive.
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
    this.isGlass = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? VSPDSRadius.card;
    final resolvedPadding = padding ?? const EdgeInsets.all(VSPDSSpacing.cardPadding);

    if (!isGlass) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        padding: resolvedPadding,
        decoration: BoxDecoration(
          color: color ?? VSPDSSemanticColors.surface,
          borderRadius: BorderRadius.circular(radius),
          border: border ??
              const Border.fromBorderSide(VSPDSBorders.subtle),
          boxShadow: const <BoxShadow>[VSPDSComponentEffects.cardShadow],
        ),
        child: child,
      );
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: VSPDSBlur.glassSigma,
            sigmaY: VSPDSBlur.glassSigma,
          ),
          child: Container(
            padding: resolvedPadding,
            decoration: BoxDecoration(
              color: color ?? VSPDSColors.glassSurface,
              borderRadius: BorderRadius.circular(radius),
              border: border ??
                  const Border.fromBorderSide(VSPDSBorders.subtle),
              boxShadow: const <BoxShadow>[VSPDSComponentEffects.glassShadow],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
