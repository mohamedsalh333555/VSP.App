import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import 'primary_button.dart';

/// Unified VSP empty/no-content state.
/// Context-specific screens provide their own icon and copy; the visual shell stays consistent.
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
        padding: const EdgeInsets.symmetric(
          horizontal: VSPEmptyStateMetrics.contentHorizontalPadding,
          vertical: VSPEmptyStateMetrics.contentVerticalPadding,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: VSPEmptyStateMetrics.iconContainerSize,
              height: VSPEmptyStateMetrics.iconContainerSize,
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPEmptyStateMetrics.iconContainerRadius),
                border: Border.all(
                  color: VSPColors.divider.withValues(alpha: 0.28),
                ),
              ),
              child: Icon(
                icon,
                color: VSPColors.textSecondary,
                size: VSPEmptyStateMetrics.iconSize,
              ),
            ),
            const SizedBox(height: VSPEmptyStateMetrics.titleGap),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: VSPColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
            ),
            const SizedBox(height: VSPEmptyStateMetrics.descriptionGap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: VSPEmptyStateMetrics.textHorizontalPadding),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: VSPColors.textSecondary,
                      fontSize: 12,
                      height: 1.55,
                    ),
              ),
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: VSPEmptyStateMetrics.actionGap),
              SizedBox(
                width: double.infinity,
                height: VSPSize.buttonHeight,
                child: PrimaryButton(
                  text: buttonText!,
                  onPressed: onButtonPressed!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
