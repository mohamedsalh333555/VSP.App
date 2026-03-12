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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? VSPColors.surface,
        borderRadius: BorderRadius.circular(borderRadius ?? VSPRadius.lg),
        border: border,
      ),
      child: child,
    );
  }
}
