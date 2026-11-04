import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/ui/tokens/vsp_design_tokens.dart';

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
      duration: VSPDSMotion.fast,
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
    )..value = 1.0;
    _scale = Tween<double>(begin: 0.90, end: 1.0).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final effectiveSize = widget.size > VSPDSAccessibility.minimumTapTarget
        ? widget.size
        : VSPDSAccessibility.minimumTapTarget;

    return Container(
      margin: widget.margin,
      width: effectiveSize,
      height: effectiveSize,
      child: Semantics(
        button: true,
                excludeSemantics: true,
        label: isRtl ? 'رجوع' : 'Back',
        onTap: () {
          HapticFeedback.lightImpact();
          if (widget.onTap != null) {
            widget.onTap!();
          } else {
            Navigator.maybePop(context);
          }
        },
        child: Material(
          color: VSPColors.transparent,
          child: InkWell(
            excludeFromSemantics: true,
            customBorder: const CircleBorder(),
            onTapDown: (_) {
          if (!MediaQuery.disableAnimationsOf(context)) _controller.reverse();
        },
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
            child: Center(
              child: ScaleTransition(
                scale: _scale,
                child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? VSPDSColors.white08,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: VSPDSColors.white12,
                    width: VSPDSBorders.standard,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: VSPDSColors.black80.withValues(alpha: 0.15),
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
                    color: widget.iconColor ?? VSPDSSemanticColors.textPrimary,
                    size: (widget.size * 0.46).clamp(14.0, 18.0),
                  ),
                ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
