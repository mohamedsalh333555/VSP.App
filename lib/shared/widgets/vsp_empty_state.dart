import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_design_tokens.dart';
import 'primary_button.dart';

/// Canonical actionable empty state backed by Design System V2.
class VSPEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const VSPEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(VSPDSSpacing.inputHorizontal),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(VSPDSizes.emptyIconPadding),
              decoration: BoxDecoration(
                color: VSPDSSemanticColors.accent.withValues(
                  alpha: VSPDSOpacity.selectedSurface,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: VSPDSSemanticColors.accent.withValues(
                    alpha: VSPDSOpacity.border,
                  ),
                  width: VSPDSBorders.focus,
                ),
              ),
              child: Icon(
                icon,
                color: VSPDSSemanticColors.accent,
                size: VSPDSizes.emptyIconSize,
              ),
            ),
            const SizedBox(height: VSPDSSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: VSPDSTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: VSPDSSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: VSPDSSpacing.md,
              ),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: VSPDSTypography.stateBody,
              ),
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: VSPDSSpacing.md),
              SizedBox(
                width: double.infinity,
                height: VSPDSizes.buttonHeight,
                child: PrimaryButton(
                  text: buttonText!,
                  onPressed: onButtonPressed,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
