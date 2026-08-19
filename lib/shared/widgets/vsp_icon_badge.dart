import 'package:flutter/material.dart';

class VSPIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double backgroundOpacity;
  final bool hasBorder;

  const VSPIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40.0,
    this.iconSize = 20.0,
    this.backgroundOpacity = 0.15,
    this.hasBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: backgroundOpacity),
        shape: BoxShape.circle,
        border: hasBorder ? Border.all(color: color.withValues(alpha: 0.3), width: 1.5) : null,
      ),
      child: Center(
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }
}
