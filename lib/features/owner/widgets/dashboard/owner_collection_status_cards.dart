import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_design_tokens.dart';

/// Operational finance visibility for amounts that are not yet fully realized
/// for the owner. Values come from the dashboard analytics SSOT.
class OwnerCollectionStatusCards extends StatelessWidget {
  final double cashUncollected;
  final double onlineUnavailable;
  final bool isArabic;
  final VoidCallback? onCashTap;
  final VoidCallback? onOnlineTap;

  const OwnerCollectionStatusCards({
    super.key,
    required this.cashUncollected,
    required this.onlineUnavailable,
    required this.isArabic,
    this.onCashTap,
    this.onOnlineTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CollectionCard(
            icon: Iconsax.money_3_copy,
            value: cashUncollected,
            title: isArabic ? 'كاش لم يُحصّل' : 'Cash awaiting collection',
            subtitle: isArabic
                ? 'مبالغ مستحقة من حجوزات اللاعبين'
                : 'Due from player bookings',
            color: VSPDSSemanticColors.warning,
            onTap: onCashTap,
            isArabic: isArabic,
          ),
        ),
        const SizedBox(width: VSPDSSpacing.xs),
        Expanded(
          child: _CollectionCard(
            icon: Iconsax.wallet_2_copy,
            value: onlineUnavailable,
            title: isArabic
                ? 'أونلاين لم يُسوَّ بعد'
                : 'Online pending settlement',
            subtitle: isArabic
                ? 'مدفوع إلكترونياً وغير متاح للسحب بعد'
                : 'Paid online, not withdrawable yet',
            color: VSPDSSemanticColors.info,
            onTap: onOnlineTap,
            isArabic: isArabic,
          ),
        ),
      ],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final IconData icon;
  final double value;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final bool isArabic;

  const _CollectionCard({
    required this.icon,
    required this.value,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.all(VSPDSSpacing.md),
      decoration: BoxDecoration(
        color: VSPDSSemanticColors.surface,
        borderRadius: BorderRadius.circular(VSPDSRadius.card),
        border: Border.all(
          color: color.withValues(alpha: VSPDSOpacity.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: VSPDSizes.iconLg, color: color),
          const SizedBox(height: VSPDSSpacing.xs),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: VSPDSTypography.labelMedium.copyWith(
              color: VSPDSSemanticColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: VSPDSSpacing.xxs),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: VSPDSTypography.bodySmall,
          ),
          const SizedBox(height: VSPDSSpacing.sm),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '\${value.toStringAsFixed(0)} \${isArabic ? 'ج.م' : 'EGP'}',
              style: VSPDSTypography.numeric.copyWith(
                fontSize: 17.0,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(height: VSPDSSpacing.xs),
            Text(
              isArabic ? 'عرض الحجوزات' : 'View bookings',
              style: VSPDSTypography.actionLabel.copyWith(color: color),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return child;
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(VSPDSRadius.card),
        onTap: onTap,
        child: child,
      ),
    );
  }
}
