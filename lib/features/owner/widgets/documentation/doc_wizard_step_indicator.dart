import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class DocWizardStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const DocWizardStepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = currentStep == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: isActive ? 24 : 8,
          height: 4,
          decoration: BoxDecoration(
            color: isActive ? VSPColors.accent : VSPColors.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
