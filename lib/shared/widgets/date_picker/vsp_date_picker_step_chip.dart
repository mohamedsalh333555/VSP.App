import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';

/// Interactive Step Tracker Chip used in the 3-step date picker.
class VspDatePickerStepChip extends StatelessWidget {
  final int stepIndex;
  final int currentStep;
  final String title;
  final String? value;
  final bool isAr;
  final bool isEnabled;
  final VoidCallback onTap;

  const VspDatePickerStepChip({
    super.key,
    required this.stepIndex,
    required this.currentStep,
    required this.title,
    this.value,
    required this.isAr,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = currentStep == stepIndex;
    final isDone = value != null;

    return Expanded(
      child: GestureDetector(
        onTap: isEnabled
            ? () {
                VSPFeedback.triggerTap();
                onTap();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isCurrent
                ? VSPColors.accent.withValues(alpha: 0.18)
                : (isDone ? VSPColors.surfaceAlt : VSPColors.surfaceAlt.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: Border.all(
              color: isCurrent
                  ? VSPColors.accent
                  : (isDone ? VSPColors.accent.withValues(alpha: 0.3) : VSPColors.divider),
              width: isCurrent ? 2.0 : 1.0,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: VSPColors.accent.withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: isCurrent ? VSPColors.accent : VSPColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value ?? (isAr ? 'اختر' : 'Select'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isCurrent ? Colors.white : (isDone ? VSPColors.textPrimary : VSPColors.textMuted),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
