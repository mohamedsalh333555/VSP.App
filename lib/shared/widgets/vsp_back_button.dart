import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// زر الرجوع الموحد لتطبيق VSP (تصميم زجاجي دائري مع أنيميشن ولمس تفاعلي)
class VSPBackButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? backgroundColor;
  final double size;
  final EdgeInsetsGeometry margin;

  const VSPBackButton({
    super.key,
    this.onTap,
    this.iconColor,
    this.backgroundColor,
    this.size = 33.0,
    this.margin = EdgeInsets.zero,
  });

  @override
  State<VSPBackButton> createState() => _VSPBackButtonState();
}

class _VSPBackButtonState extends State<VSPBackButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
      lowerBound: 0.90,
      upperBound: 1.0,
    )..value = 1.0;
    _scale = Tween<double>(begin: 1.0, end: 0.90).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final effectiveSize = widget.size > 44.0 ? widget.size : 44.0;

    return Container(
      margin: widget.margin,
      width: effectiveSize,
      height: effectiveSize,
      alignment: Alignment.center,
      child: ScaleTransition(
        scale: _scale,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _controller.reverse(),
          onTapUp: (_) => _controller.forward(),
          onTapCancel: () => _controller.forward(),
          onTap: () {
            HapticFeedback.lightImpact();
            if (widget.onTap != null) {
              widget.onTap!();
            } else {
              Navigator.maybePop(context);
            }
          },
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                isRtl
                    ? Iconsax.arrow_right_3_copy
                    : Iconsax.arrow_left_2_copy,
                color: widget.iconColor ?? Colors.white,
                size: (widget.size * 0.46).clamp(14.0, 18.0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
