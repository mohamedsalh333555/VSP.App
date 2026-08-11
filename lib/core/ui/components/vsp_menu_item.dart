import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../tokens/vsp_tokens.dart';

class VSPMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLogout;

  const VSPMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VSPRadius.md),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: VSPSpacing.sm),
        child: Row(
          children: [
            // Icon Box
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isLogout 
                    ? VSPColors.error.withValues(alpha: 0.1) 
                    : VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.md),
              ),
              child: Icon(
                icon,
                color: isLogout ? VSPColors.error : VSPColors.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: VSPSpacing.md),
            
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 16,
                          color: isLogout ? VSPColors.error : VSPColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: VSPSpacing.xs),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isLogout 
                              ? VSPColors.error.withValues(alpha: 0.7) 
                              : VSPColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            
            // Chevron (RTL Directional compliant)
            if (!isLogout)
              Icon(
                Localizations.localeOf(context).languageCode == 'ar' ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_3_copy,
                color: VSPColors.textSecondary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

