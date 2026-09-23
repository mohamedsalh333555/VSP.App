import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';
import 'insights_revenue_sources_card.dart';

/// Card showing distribution of bookings across categories: Direct/Personal, Challenges, and Open-Join.
class InsightsBookingTypesCard extends StatelessWidget {
  final int totalBookings;
  final int personalCount;
  final double personalPct;
  final int challengeCount;
  final double challengePct;
  final int openJoinCount;
  final double openJoinPct;
  final bool isArabic;

  const InsightsBookingTypesCard({
    super.key,
    required this.totalBookings,
    required this.personalCount,
    required this.personalPct,
    required this.challengeCount,
    required this.challengePct,
    required this.openJoinCount,
    required this.openJoinPct,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.category_copy, size: 15, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'أنواع الحجوزات' : 'BOOKING TYPES',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                isArabic ? 'إجمالي $totalBookings حجز' : '$totalBookings total',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (totalBookings == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                isArabic ? 'لا توجد حجوزات مسجلة بعد.' : 'No bookings registered yet.',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            )
          else ...[
            FramedMetricProgressBar(
              title: isArabic ? 'حجوزات عادية ومباشرة' : 'Direct & Standard',
              amount: personalCount.toDouble(),
              percentage: personalPct,
              color: VSPColors.accent,
              isArabic: isArabic,
              unit: isArabic ? 'حجز' : 'bookings',
            ),
            const SizedBox(height: 14),
            FramedMetricProgressBar(
              title: isArabic ? 'تحديات ومباريات فرق' : 'Team Challenges',
              amount: challengeCount.toDouble(),
              percentage: challengePct,
              color: Colors.white70,
              isArabic: isArabic,
              unit: isArabic ? 'حجز' : 'bookings',
            ),
            if (openJoinCount > 0) ...[
              const SizedBox(height: 14),
              FramedMetricProgressBar(
                title: isArabic ? 'مباريات انضمام وتجميع' : 'Open-Join Matches',
                amount: openJoinCount.toDouble(),
                percentage: openJoinPct,
                color: Colors.white38,
                isArabic: isArabic,
                unit: isArabic ? 'حجز' : 'bookings',
              ),
            ],
          ],
        ],
      ),
    );
  }
}
