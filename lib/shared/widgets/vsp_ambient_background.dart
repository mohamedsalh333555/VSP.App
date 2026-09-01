import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

/// Reusable Ambient Background wrapper that provides a signature subtle neon glow
/// in the background layers while completely isolating touch gestures (zero hit-test interference).
class VSPAmbientBackground extends StatelessWidget {
  final Widget child;
  final bool showTopGlow;
  final bool showBottomGlow;
  final Color? glowColor;
  final Color backgroundColor;

  const VSPAmbientBackground({
    super.key,
    required this.child,
    this.showTopGlow = true,
    this.showBottomGlow = false,
    this.glowColor,
    this.backgroundColor = VSPColors.background,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGlowColor = glowColor ?? VSPColors.accentGlow;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Container(
      color: backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Ambient Glow Layer (Purely Visual - completely ignored by gesture detector)
          IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (showTopGlow)
                  Positioned(
                    top: -100,
                    right: isRtl ? null : -100,
                    left: isRtl ? -100 : null,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: effectiveGlowColor,
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),
                if (showBottomGlow)
                  Positioned(
                    bottom: -80,
                    left: isRtl ? null : -80,
                    right: isRtl ? -80 : null,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: effectiveGlowColor.withValues(alpha: 0.08),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 2. Interactive Foreground Child
          child,
        ],
      ),
    );
  }
}
