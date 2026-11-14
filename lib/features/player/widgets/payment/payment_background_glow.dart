import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_design_tokens.dart';

/// Neutral charcoal decoration; lime glow is disabled by the design system.
class PaymentBackgroundGlow extends StatelessWidget {
  const PaymentBackgroundGlow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      top: -100,
      right: -100,
      child: SizedBox(
        width: 300,
        height: 300,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: VSPDSSemanticColors.background,
          ),
        ),
      ),
    );
  }
}
