import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

class VSPIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final bool hasBorder;
  final Color? borderColor;

  const VSPIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40.0,
    this.iconSize = 20.0,
    this.backgroundColor,
    this.hasBorder = false,
    this.borderColor,
    @Deprecated('Use backgroundColor instead of low-opacity tint')
    double? backgroundOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? VSPColors.iconBadgeBg,
        shape: BoxShape.circle,
        border: hasBorder
            ? Border.all(
                color: borderColor ?? color.withValues(alpha: 0.25),
                width: 1.0,
              )
            : null,
      ),
      child: Center(
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }
}
