import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../tokens/vsp_design_tokens.dart';

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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final accent = isLogout
        ? VSPDSSemanticColors.error
        : VSPDSSemanticColors.accent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VSPDSRadius.md),
      child: Container(
        constraints: const BoxConstraints(
          minHeight: VSPDSizes.touchTarget,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: VSPDSSpacing.xs,
        ),
        child: Row(
          textDirection: Directionality.of(context),
          children: [
            Container(
              width: VSPDSizes.avatarMd,
              height: VSPDSizes.avatarMd,
              decoration: BoxDecoration(
                color: isLogout
                    ? accent.withValues(alpha: VSPDSOpacity.selectedSurface)
                    : VSPDSSemanticColors.iconBadge,
                borderRadius: BorderRadius.circular(VSPDSRadius.md),
              ),
              child: Icon(
                icon,
                color: accent,
                size: VSPDSizes.iconLg,
              ),
            ),
            const SizedBox(width: VSPDSSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: VSPDSTypography.titleLarge.copyWith(
                      fontSize: 16,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: VSPDSSpacing.xxs),
                  Text(
                    subtitle,
                    style: VSPDSTypography.bodyMedium.copyWith(
                      color: isLogout
                          ? accent.withValues(alpha: VSPDSOpacity.secondaryText)
                          : VSPDSSemanticColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLogout)
              Icon(
                isArabic
                    ? Iconsax.arrow_left_2_copy
                    : Iconsax.arrow_right_1_copy,
                color: VSPDSSemanticColors.textSecondary,
                size: VSPDSizes.iconCompact,
              ),
          ],
        ),
      ),
    );
  }
}
