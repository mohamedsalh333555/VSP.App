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
          horizontal: VSPSpacing.xl,
          vertical: VSPSpacing.xl,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: VSPColors.divider.withValues(alpha: 0.28),
                ),
              ),
              child: Icon(
                icon,
                color: VSPColors.textSecondary,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
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
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
              const SizedBox(height: VSPSpacing.lg),
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
