import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Decorative neon blurred glow in the background of the payment checkout screen.
class PaymentBackgroundGlow extends StatelessWidget {
  const PaymentBackgroundGlow({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -100,
      right: -100,
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: VSPColors.accent.withValues(alpha: 0.12),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }
}
