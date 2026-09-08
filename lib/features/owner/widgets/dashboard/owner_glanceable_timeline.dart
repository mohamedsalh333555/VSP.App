import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/app_date_formatter.dart';
import '../../../../core/utils/vsp_launcher_utils.dart';
import '../../../../data/models.dart';
import '../../screens/owner_bookings_screen.dart';

/// جدول حجوزات اليوم الموحد
class OwnerGlanceableTimeline extends StatelessWidget {
  final List<Booking> allBookings;
  final String selectedStadiumFilter;
  final bool isArabic;
  final VoidCallback onNavigateToBookings;

  const OwnerGlanceableTimeline({
    super.key,
    required this.allBookings,
    required this.selectedStadiumFilter,
    required this.isArabic,
    required this.onNavigateToBookings,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final String locale = isArabic ? 'ar' : 'en';

    final todayBookings = allBookings.where((b) {
      if (b.status == BookingStatus.cancelled) return false;
      if (selectedStadiumFilter != 'all' && b.stadiumId != selectedStadiumFilter) return false;
      final bStart = b.startTime.toLocal();
      return bStart.year == now.year && bStart.month == now.month && bStart.day == now.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'حجوزات اليوم' : "Today's Bookings",
              style: const TextStyle(
                color: VSPColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerBookingsScreen()));
              },
              child: Text(
                isArabic ? 'عرض الكل' : 'View All',
                style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (todayBookings.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                const Icon(Iconsax.calendar_tick_copy, size: 28, color: Colors.white54),
                const SizedBox(height: 8),
                Text(
                  isArabic ? 'لا توجد حجوزات مسجلة اليوم' : 'No bookings recorded today',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onNavigateToBookings();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                    decoration: BoxDecoration(
                      color: VSPColors.accent,
                      borderRadius: BorderRadius.circular(VSPRadius.full),
                    ),
                    child: Text(
                      isArabic ? 'إدارة الحجوزات' : 'Manage Bookings',
                      style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: todayBookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final b = todayBookings[index];
              final isOngoing = now.isAfter(b.startTime.toLocal()) && now.isBefore(b.endTime.toLocal());
              final isPassed = now.isAfter(b.endTime.toLocal());

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isOngoing ? const Color(0xFF12231A) : VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(
                    color: isOngoing
                        ? VSPColors.accent.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isOngoing
                            ? VSPColors.accentSoft
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(VSPRadius.sm),
                      ),
                      child: Text(
                        AppDateFormatter.formatTime(b.startTime.toLocal(), locale),
                        style: TextStyle(
                          color: isOngoing ? VSPColors.accent : VSPColors.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (b.hostName != null && b.hostName!.isNotEmpty) ? b.hostName! : (isArabic ? 'حجز ملعب' : 'Booking'),
                            style: TextStyle(
                              color: isPassed ? VSPColors.textSecondary : VSPColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              decoration: isPassed ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${b.totalPrice > 0 ? b.totalPrice.toStringAsFixed(0) : b.depositPaid.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 6),
                              Text('•', style: TextStyle(color: Colors.white.withValues(alpha: 0.2))),
                              const SizedBox(width: 6),
                              Text(
                                b.isPaid ? (isArabic ? 'مدفوع' : 'Paid') : (isArabic ? 'كاش' : 'Cash'),
                                style: TextStyle(
                                  color: b.isPaid ? VSPColors.accent : Colors.white60,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (b.playerPhone != null && b.playerPhone!.isNotEmpty && !isPassed) ...[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Iconsax.call_copy, size: 17, color: Colors.white70),
                        onPressed: () => VSPLauncherUtils.makePhoneCall(context, b.playerPhone!),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Iconsax.message_copy, size: 17, color: Colors.white70),
                        onPressed: () => VSPLauncherUtils.openWhatsApp(
                          context,
                          phone: b.playerPhone!,
                          message: isArabic ? 'مرحباً كابتن ${b.hostName ?? ""}، بخصوص حجزك اليوم...' : 'Hi Captain ${b.hostName ?? ""}, regarding your booking today...',
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
