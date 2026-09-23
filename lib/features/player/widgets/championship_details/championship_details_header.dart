import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/vsp_countdown_timer.dart';
import '../../../../shared/widgets/vsp_icon_badge.dart';

/// بطاقة إحصائية مدمجة لبيانات البطولة
class ChampionshipStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const ChampionshipStatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: VSPColors.background,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(color: VSPColors.divider, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 9),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 11),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ترويسة تفاصيل البطولة الزجاجية الفاخرة (الشعار، الحالة، العداد التنازلي، توثيق تسليم الجوائز، وشريط الإحصائيات)
class ChampionshipDetailsHeader extends StatelessWidget {
  final Championship championship;
  final bool isFull;
  final String startDateDisplay;

  const ChampionshipDetailsHeader({
    super.key,
    required this.championship,
    required this.isFull,
    required this.startDateDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(VSPSpacing.md),
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              championship.logoUrl.isNotEmpty
                  ? Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: VSPColors.accent, width: 1.5),
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: championship.logoUrl,
                          memCacheWidth: 150,
                          memCacheHeight: 150,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const VSPIconBadge(
                            icon: Iconsax.cup_copy,
                            color: VSPColors.accent,
                            size: 50,
                            iconSize: 24,
                            hasBorder: true,
                          ),
                        ),
                      ),
                    )
                  : const VSPIconBadge(
                      icon: Iconsax.cup_copy,
                      color: VSPColors.accent,
                      size: 50,
                      iconSize: 24,
                      hasBorder: true,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      championship.name,
                      style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Iconsax.location_copy, color: VSPColors.textSecondary, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          championship.governorate.isNotEmpty
                              ? championship.governorate
                              : (isArabic ? 'مصر' : 'Egypt'),
                          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isFull || championship.status != 'open')
                      ? VSPColors.error.withValues(alpha: 0.15)
                      : VSPColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(VSPRadius.sm),
                ),
                child: Text(
                  isFull
                      ? (isArabic ? 'مكتمل العدد' : 'Full')
                      : (championship.status == 'open'
                          ? (isArabic ? 'مفتوح للتسجيل' : 'Open')
                          : championship.status.toUpperCase()),
                  style: TextStyle(
                    color: (isFull || championship.status != 'open') ? VSPColors.error : VSPColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          if (championship.status == 'open' && !isFull && championship.startDate.isAfter(DateTime.now())) ...[
            const SizedBox(height: 12),
            VSPCountdownTimer(targetDate: championship.startDate),
          ],
          if (championship.status == 'completed') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: championship.prizeDelivered
                    ? VSPColors.success.withValues(alpha: 0.1)
                    : VSPColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(
                  color: championship.prizeDelivered
                      ? VSPColors.success.withValues(alpha: 0.3)
                      : VSPColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    championship.prizeDelivered ? Iconsax.verify_copy : Iconsax.clock_copy,
                    color: championship.prizeDelivered ? VSPColors.success : VSPColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      championship.prizeDelivered
                          ? (isArabic
                              ? 'تم تسليم الجائزة المالية للبطل وتوثيقها رسمياً'
                              : 'Prize officially delivered to champion')
                          : (isArabic
                              ? 'بانتظار تسليم الجائزة المالية للبطل'
                              : 'Pending prize delivery to champion'),
                      style: TextStyle(
                        color: championship.prizeDelivered ? VSPColors.success : VSPColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Stats Grid
          Row(
            children: [
              ChampionshipStatCard(
                icon: Iconsax.cup_copy,
                iconColor: VSPColors.accent,
                label: isArabic ? 'الجائزة' : 'Prize',
                value: championship.prizePool > 0
                    ? '${championship.prizePool.toInt()} ${isArabic ? "ج.م" : "EGP"}'
                    : (championship.grandPrize > 0
                        ? '${championship.grandPrize.toInt()} ${isArabic ? "ج.م" : "EGP"}'
                        : (isArabic ? 'كأس وميداليات' : 'Cup & Medals')),
              ),
              const SizedBox(width: 8),
              ChampionshipStatCard(
                icon: Iconsax.card_copy,
                iconColor: VSPColors.accent,
                label: isArabic ? 'رسوم الاشتراك' : 'Entry Fee',
                value: '${championship.entryFee.toInt()} ${isArabic ? "ج.م" : "EGP"}',
              ),
              const SizedBox(width: 8),
              ChampionshipStatCard(
                icon: Iconsax.calendar_1_copy,
                iconColor: VSPColors.accent,
                label: isArabic ? 'الموعد' : 'Date',
                value: startDateDisplay,
              ),
              const SizedBox(width: 8),
              ChampionshipStatCard(
                icon: Iconsax.people_copy,
                iconColor: VSPColors.accent,
                label: isArabic ? 'الفرق' : 'Teams',
                value: '${championship.joinedTeams.length}/${championship.maxTeams}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
