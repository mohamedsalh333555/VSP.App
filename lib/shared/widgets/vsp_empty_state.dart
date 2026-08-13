import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import 'primary_button.dart';

/// شاشة حالة الفراغ الموجهة (Actionable Empty State - الصفحة 8 و 9 من كتاب UX Playbook)
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
        padding: const EdgeInsets.all(VSPSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // أيقونة خلفية مع إضاءة نيون هادئة (الصفحة 8)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: VSPColors.accent.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                color: VSPColors.accent,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: VSPColors.textSecondary,
                      height: 1.6,
                      fontSize: 12.5,
                    ),
              ),
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: 220,
                height: 48, // ارتفاع مريح للإبهام (الصفحات 6 و 9)
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
