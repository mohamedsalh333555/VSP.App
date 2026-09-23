import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';

/// 2x2 grid of strategic KPI metric cards (Bookings, Lost Revenue, Occupancy, Ticket Price).
/// Each card is interactive and triggers a detailed explanatory bottom sheet on tap.
class InsightsStrategicKpisGrid extends StatelessWidget {
  final int totalBookingsToday;
  final int onlinePaidCount;
  final double lostRevenue;
  final double unbookedHours;
  final double occupancyRate;
  final double totalHoursBookedToday;
  final double totalAvailableHours;
  final double averageBookingPrice;
  final bool isArabic;

  const InsightsStrategicKpisGrid({
    super.key,
    required this.totalBookingsToday,
    required this.onlinePaidCount,
    required this.lostRevenue,
    required this.unbookedHours,
    required this.occupancyRate,
    required this.totalHoursBookedToday,
    required this.totalAvailableHours,
    required this.averageBookingPrice,
    required this.isArabic,
  });

  static void showKpiExplanationSheet(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required String explanation,
    required bool isArabic,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VSPColors.surface,
      barrierColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
        side: BorderSide(color: VSPColors.divider, width: 1),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Grabber Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: VSPColors.textMuted,
                      borderRadius: BorderRadius.circular(VSPRadius.xs),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Icon + Title + Value
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(VSPRadius.chip),
                        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Iconsax.info_circle_copy, size: 20, color: VSPColors.accent),
                    ),
                    const SizedBox(width: VSPSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: VSPColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            style: const TextStyle(
                              color: VSPColors.accent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ).merge(VSPTypography.numericStyle),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: VSPSpacing.lg),

                // Explanation Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(VSPRadius.input),
                    border: Border.all(color: VSPColors.divider),
                  ),
                  child: Text(
                    explanation,
                    style: const TextStyle(
                      color: VSPColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: VSPColors.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.chip),
                      ),
                      backgroundColor: VSPColors.surfaceAlt,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      isArabic ? 'إغلاق' : 'Close',
                      style: const TextStyle(
                        color: VSPColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFramedKpiCard({
    required IconData icon,
    required String value,
    required String label,
    required String subtext,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(VSPRadius.md),
        splashColor: Colors.white.withValues(alpha: 0.05),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: Border.all(color: VSPColors.divider, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                      border: Border.all(color: VSPColors.divider),
                    ),
                    child: Icon(icon, size: 16, color: VSPColors.textSecondary),
                  ),
                  const Icon(
                    Iconsax.info_circle_copy,
                    size: 13,
                    color: VSPColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: VSPColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ).merge(VSPTypography.numericStyle),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtext,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: VSPColors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Row 1: Bookings Today + Lost Potential
        Row(
          children: [
            Expanded(
              child: _buildFramedKpiCard(
                icon: Iconsax.calendar_1_copy,
                value: '$totalBookingsToday',
                label: isArabic ? 'حجوزات اليوم' : 'Bookings Today',
                subtext: isArabic
                    ? '$onlinePaidCount أونلاين • ${totalBookingsToday - onlinePaidCount} كاش'
                    : '$onlinePaidCount online • ${totalBookingsToday - onlinePaidCount} cash',
                onTap: () => showKpiExplanationSheet(
                  context,
                  title: isArabic ? 'حجوزات اليوم' : 'Bookings Today',
                  value: isArabic
                      ? '$totalBookingsToday حجز ($onlinePaidCount أونلاين • ${totalBookingsToday - onlinePaidCount} كاش)'
                      : '$totalBookingsToday bookings ($onlinePaidCount online • ${totalBookingsToday - onlinePaidCount} cash)',
                  icon: Iconsax.calendar_1_copy,
                  explanation: isArabic
                      ? 'يمثل إجمالي عدد الحجوزات المؤكدة لملعبك خلال ساعات اليوم، مع تصنيف فوري للحجوزات المدفوعة إلكترونياً (أونلاين) والحجوزات النقدية (كاش) لتسهيل مراجعة الخزينة.'
                      : 'Represents the total confirmed bookings for your venue today, with a breakdown between digital online payments and cash collections.',
                  isArabic: isArabic,
                ),
              ),
            ),
            const SizedBox(width: VSPSpacing.md),
            Expanded(
              child: _buildFramedKpiCard(
                icon: Iconsax.moneys_copy,
                value: '${lostRevenue.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                label: isArabic ? 'الإيراد غير المستغل' : 'Lost Potential',
                subtext: isArabic
                    ? '${unbookedHours.toStringAsFixed(unbookedHours % 1 == 0 ? 0 : 1)} ساعة شاغرة'
                    : '${unbookedHours.toStringAsFixed(1)} unbooked hrs',
                onTap: () => showKpiExplanationSheet(
                  context,
                  title: isArabic ? 'الإيراد غير المستغل' : 'Lost Potential Revenue',
                  value: isArabic
                      ? '${lostRevenue.toStringAsFixed(0)} ج.م (${unbookedHours.toStringAsFixed(unbookedHours % 1 == 0 ? 0 : 1)} ساعة شاغرة اليوم)'
                      : '${lostRevenue.toStringAsFixed(0)} EGP (${unbookedHours.toStringAsFixed(1)} unbooked hrs today)',
                  icon: Iconsax.moneys_copy,
                  explanation: isArabic
                      ? 'القيمة المالية التقديرية للساعات الشاغرة التي لم تُحجز اليوم حتى الآن بناءً على سعر الساعة للملعب. يوضح لك هذا الرقم الإيراد المفقود الذي كان بإمكانك تحقيقه إذا عمل الملعب بكامل طاقته.'
                      : 'The estimated financial value of unbooked hours today based on your hourly pitch rate. Shows the missed revenue opportunity.',
                  isArabic: isArabic,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: VSPSpacing.md),

        // Row 2: Actual Occupancy + Avg Ticket Price
        Row(
          children: [
            Expanded(
              child: _buildFramedKpiCard(
                icon: Iconsax.chart_square_copy,
                value: '${occupancyRate.toStringAsFixed(0)}%',
                label: isArabic ? 'نسبة الإشغال الفعلية' : 'Actual Occupancy',
                subtext: isArabic
                    ? '${totalHoursBookedToday.toStringAsFixed(1)} من ${totalAvailableHours.toStringAsFixed(0)} ساعة'
                    : '${totalHoursBookedToday.toStringAsFixed(1)} of ${totalAvailableHours.toStringAsFixed(0)} hrs',
                onTap: () => showKpiExplanationSheet(
                  context,
                  title: isArabic ? 'نسبة الإشغال الفعلية' : 'Actual Occupancy Rate',
                  value: isArabic
                      ? '${occupancyRate.toStringAsFixed(0)}% (${totalHoursBookedToday.toStringAsFixed(1)} من ${totalAvailableHours.toStringAsFixed(0)} ساعة متاحة)'
                      : '${occupancyRate.toStringAsFixed(0)}% (${totalHoursBookedToday.toStringAsFixed(1)} of ${totalAvailableHours.toStringAsFixed(0)} available hrs)',
                  icon: Iconsax.chart_square_copy,
                  explanation: isArabic
                      ? 'النسبة المئوية لعدد الساعات المحجوزة بالفعل اليوم مقارنة بإجمالي عدد الساعات التشغيلية المتاحة في الملعب خلال 24 ساعة.'
                      : 'The percentage of operational hours actually booked today compared to the total available hours.',
                  isArabic: isArabic,
                ),
              ),
            ),
            const SizedBox(width: VSPSpacing.md),
            Expanded(
              child: _buildFramedKpiCard(
                icon: Iconsax.ticket_copy,
                value: '${averageBookingPrice.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                label: isArabic ? 'متوسط سعر الحجز' : 'Avg. Ticket Price',
                subtext: isArabic ? 'لكل حجز مسجل اليوم' : 'per registered booking',
                onTap: () => showKpiExplanationSheet(
                  context,
                  title: isArabic ? 'متوسط سعر الحجز' : 'Average Booking Price',
                  value: isArabic
                      ? '${averageBookingPrice.toStringAsFixed(0)} ج.م لكل حجز مسجل'
                      : '${averageBookingPrice.toStringAsFixed(0)} EGP per registered booking',
                  icon: Iconsax.ticket_copy,
                  explanation: isArabic
                      ? 'متوسط الإيراد الناتج عن كل حجز تم تسجيله اليوم، ويتم حسابه بقسمة إجمالي إيرادات اليوم على عدد الحجوزات.'
                      : 'The average revenue generated per booking today, calculated by dividing total daily revenue by total bookings count.',
                  isArabic: isArabic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
