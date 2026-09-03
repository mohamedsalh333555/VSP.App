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
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            effectiveGlowColor.withValues(alpha: 0.20),
                            effectiveGlowColor.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                if (showBottomGlow)
                  Positioned(
                    bottom: -80,
                    left: isRtl ? null : -80,
                    right: isRtl ? -80 : null,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            effectiveGlowColor.withValues(alpha: 0.15),
                            effectiveGlowColor.withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
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
