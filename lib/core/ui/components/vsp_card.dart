import 'package:flutter/material.dart';
import '../tokens/vsp_tokens.dart';

enum VSPCardVariant { standard, glass, accentGlow, highlight }

class VSPCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool isGlowBorder;
  final VSPCardVariant variant;
  final double? width;
  final double? height;
  final Border? border;
  final Color? backgroundColor;
  final Color? color;
  final bool isGlass;

  const VSPCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.isGlowBorder = false,
    this.variant = VSPCardVariant.standard,
    this.width,
    this.height,
    this.border,
    this.backgroundColor,
    this.color,
    this.isGlass = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(VSPRadius.lg);
    final effectiveColor = color ?? backgroundColor;
    final useGlowBorder = isGlowBorder || variant == VSPCardVariant.accentGlow;

    return Container(
      width: width,
      height: height,
      margin: margin ?? const EdgeInsets.only(bottom: VSPSpacing.md),
      decoration: BoxDecoration(
        color: effectiveColor ?? VSPColors.surface,
        borderRadius: radius,
        border: border ?? Border.all(
          color: useGlowBorder ? VSPColors.borderAccent : VSPColors.borderLight,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: VSPColors.accent.withValues(alpha: 0.1),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: padding ?? const EdgeInsets.all(VSPSpacing.lg),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}