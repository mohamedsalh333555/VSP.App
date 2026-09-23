import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../owner_booking_sheet.dart';

/// كارت جدول "ملعبك النهارده" التشغيلي الفوري بالنقط الملونة (فحمي وأخضر نيون)
class OwnerTodayPitchScheduleCard extends StatelessWidget {
  final List<Booking> allBookings;
  final List<Stadium> stadiums;
  final String selectedStadiumFilter;
  final bool isArabic;
  final VoidCallback onNavigateToBookings;

  const OwnerTodayPitchScheduleCard({
    super.key,
    required this.allBookings,
    required this.stadiums,
    required this.selectedStadiumFilter,
    required this.isArabic,
    required this.onNavigateToBookings,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // 1. استخراج حجوزات اليوم الحالي (مع استبعاد الملغي وتطبيق فلتر الملعب)
    final todayBookings = allBookings.where((b) {
      if (b.status == BookingStatus.cancelled) return false;
      if (selectedStadiumFilter != 'all' && b.stadiumId != selectedStadiumFilter) {
        return false;
      }
      return b.startTime.isAfter(todayStart) && b.startTime.isBefore(todayEnd);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── عنوان القسم: ملعبك النهارده ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'ملعبك النهارده' : "Today's Schedule",
                style: const TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (todayBookings.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onNavigateToBookings();
                  },
                  child: Text(
                    isArabic ? 'عرض الكل' : 'View All',
                    style: const TextStyle(
                      color: VSPColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── قائمة مواعيد اليوم ──
        if (todayBookings.isEmpty)
          _buildEmptyTodayState(context)
        else
          ...todayBookings.map((b) => _buildBookingRow(context, b)),
      ],
    );
  }

  Widget _buildBookingRow(BuildContext context, Booking booking) {
    final isPending = booking.status == BookingStatus.pending ||
        booking.paymentStatus == 'pending' ||
        booking.paymentStatus == 'unpaid';

    final isConfirmed = booking.status == BookingStatus.confirmed ||
        booking.isPaid ||
        booking.paymentStatus == 'paid';

    final Color dotColor = isPending
        ? const Color(0xFFF59E0B) // برتقالي هادئ للمنتظر
        : (isConfirmed ? VSPColors.accent : const Color(0xFF71717A));

    final String statusLabel = isPending
        ? (isArabic ? 'في انتظار الدفع' : 'Awaiting Payment')
        : (isConfirmed ? (isArabic ? 'مؤكد' : 'Confirmed') : (isArabic ? 'غير مؤكد' : 'Unconfirmed'));

    final Color statusColor = isPending
        ? const Color(0xFFF59E0B)
        : VSPColors.textSecondary;

    // استخراج الاسم وتوقيت الحجز
    final timeStr = DateFormat('h:mm a', isArabic ? 'ar' : 'en').format(booking.startTime.toLocal());
    final partyName = booking.playerTeamName ?? booking.hostName ?? (isArabic ? 'حجز ملعب' : 'Booking');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: VSPColors.surface, // #18181B الفحمي
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider, width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(VSPRadius.md),
          onTap: () {
            HapticFeedback.lightImpact();
            if (stadiums.isEmpty) {
              onNavigateToBookings();
              return;
            }

            final stadium = stadiums.firstWhere(
              (s) => s.id == booking.stadiumId,
              orElse: () => stadiums.first,
            );

            showOwnerBookingModal(
              context: context,
              isEdit: true,
              slot: {
                'booking': booking,
                'name': booking.playerTeamName ?? booking.hostName ?? '',
                'slotTime': booking.startTime,
                'price': booking.totalPrice,
                'status': booking.isPaid ? 'booked' : 'pending',
              },
              selectedStadium: stadium,
              baseDate: booking.startTime,
              selectedDayIndex: 0,
              parentContext: context,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                // النقطة الملونة الذكية
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),

                // الساعة واسم الحاجز
                Expanded(
                  child: Text(
                    '$timeStr — $partyName',
                    style: const TextStyle(
                      color: VSPColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(width: 8),

                // نص الحالة على اليسار
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11.5,
                    fontWeight: isPending ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTodayState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF71717A),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isArabic ? 'لا توجد حجوزات مقررة لباقي اليوم' : 'No bookings scheduled for today',
                style: const TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Text('—', style: TextStyle(color: VSPColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                onNavigateToBookings();
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: VSPColors.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VSPRadius.sm),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(
                isArabic ? '+ تسجيل حجز يدوي سريع للملعب' : '+ Quick Walk-in Booking',
                style: const TextStyle(
                  color: VSPColors.accent,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
