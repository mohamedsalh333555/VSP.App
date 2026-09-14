import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/services/vsp_time_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../quick_phone_booking_modal.dart';
import 'owner_slot_card.dart';

/// Row widget rendering the time label alongside the dynamic OwnerSlotCard,
/// equipped with Quick Phone Booking tap & long-press shortcuts.
class OwnerTimeSlotRow extends StatelessWidget {
  final Map<String, dynamic> slot;
  final Stadium selectedStadium;
  final List<Map<String, dynamic>> allRawSlots;
  final int selectedDayIndex;
  final DateTime baseDate;
  final VoidCallback onQuickBookingDone;
  final void Function({required bool isEdit, required Map<String, dynamic> slot, required Stadium stadium})
      onShowBookingModal;

  const OwnerTimeSlotRow({
    super.key,
    required this.slot,
    required this.selectedStadium,
    required this.allRawSlots,
    required this.selectedDayIndex,
    required this.baseDate,
    required this.onQuickBookingDone,
    required this.onShowBookingModal,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMerged = slot['merged'] == true;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleTap(context),
      onLongPress: () => _handleLongPress(context),
      child: Row(
        crossAxisAlignment: isMerged ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          // Time Column
          SizedBox(
            width: 75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slot['time'].replaceAll(' ', ''),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: VSPColors.textSecondary,
                        fontSize: 12,
                      ),
                ),
                if (isMerged) ...[
                  const SizedBox(height: 2),
                  Text(
                    slot['endTimeStr'] as String,
                    style: const TextStyle(
                      color: VSPColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if ((slot['nightLabel'] as String?)?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 2),
                  Text(
                    slot['nightLabel'] as String,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Interactive Slot Card
          Expanded(
            child: OwnerSlotCard(slot: slot),
          ),
        ],
      ),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    if (slot['type'] == 'empty') {
      final now = VSPTimeService.now;
      final DateTime? slotTime = slot['slotTime'] as DateTime?;
      final bool isPast = slotTime != null && now.isAfter(slotTime.add(const Duration(minutes: 15)));

      if (isPast) {
        HapticFeedback.lightImpact();
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        VSPFeedback.showWarning(
          context,
          isAr
              ? 'هذا الموعد منقضي، يرجى اختيار موعد قادم.'
              : 'This slot has expired. Please choose an upcoming slot.',
        );
        return;
      }

      final selectedDate = baseDate.add(Duration(days: selectedDayIndex));
      final startTime = (slot['slotTime'] as DateTime?) ??
          DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            slot['hour'] as int,
            slot['minute'] as int,
          );
      final endTime = startTime.add(const Duration(minutes: 60));

      // Calculate consecutive available minutes until next obstacle (break, booking, closing)
      int maxAvailableMinutes = 60;
      String nextObstacleType = 'none';
      DateTime? nextObstacleTime;

      final startIdx = allRawSlots.indexWhere((s) {
        final st = s['slotTime'] as DateTime?;
        return st != null &&
            st.year == startTime.year &&
            st.month == startTime.month &&
            st.day == startTime.day &&
            st.hour == startTime.hour &&
            st.minute == startTime.minute;
      });

      if (startIdx != -1) {
        int consecutiveEmpty = 0;
        for (int i = startIdx; i < allRawSlots.length; i++) {
          final raw = allRawSlots[i];
          if (raw['type'] == 'empty') {
            consecutiveEmpty++;
          } else {
            nextObstacleType = raw['type'] == 'break' ? 'break' : 'booking';
            nextObstacleTime = raw['slotTime'] as DateTime?;
            break;
          }
        }
        if (nextObstacleType == 'none' && (startIdx + consecutiveEmpty >= allRawSlots.length)) {
          nextObstacleType = 'closing';
          if (allRawSlots.isNotEmpty) {
            final lastSlot = allRawSlots.last;
            final lastTime = lastSlot['slotTime'] as DateTime?;
            if (lastTime != null) {
              nextObstacleTime = lastTime.add(const Duration(minutes: 30));
            }
          }
        }
        maxAvailableMinutes = consecutiveEmpty * 30;
      }

      final booked = await QuickPhoneBookingModal.show(
        context,
        stadium: selectedStadium,
        date: selectedDate,
        slotTime: slot['time'] as String? ?? '08:00 PM - 09:00 PM',
        startTime: startTime,
        endTime: endTime,
        defaultPrice: selectedStadium.pricePerHour,
        maxAvailableMinutes: maxAvailableMinutes,
        nextObstacleType: nextObstacleType,
        nextObstacleTime: nextObstacleTime,
      );

      if (booked == true) {
        onQuickBookingDone();
      }
    } else if (slot['isManaged'] == true) {
      onShowBookingModal(isEdit: true, slot: slot, stadium: selectedStadium);
    }
  }

  Future<void> _handleLongPress(BuildContext context) async {
    if (slot['type'] == 'empty') {
      final now = DateTime.now();
      final DateTime? slotTime = slot['slotTime'] as DateTime?;
      final bool isToday = selectedDayIndex == 0;
      final bool isPast = isToday && slotTime != null && now.isAfter(slotTime.add(const Duration(minutes: 15)));

      if (isPast) {
        HapticFeedback.lightImpact();
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        VSPFeedback.showWarning(
          context,
          isAr
              ? 'هذا الموعد منقضي، يرجى اختيار موعد قادم.'
              : 'This slot has expired. Please choose an upcoming slot.',
        );
        return;
      }

      HapticFeedback.mediumImpact();
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uid = auth.currentUser?.id;
      if (uid == null) return;

      final selectedDate = baseDate.add(Duration(days: selectedDayIndex));
      final startTime = (slot['slotTime'] as DateTime?) ??
          DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            slot['hour'] as int,
            slot['minute'] as int,
          );
      final endTime = startTime.add(const Duration(minutes: 60));

      final draft = BookingDraft(
        stadiumId: selectedStadium.id,
        stadiumName: selectedStadium.name,
        stadiumImageUrl: selectedStadium.imageUrl,
        ownerId: selectedStadium.ownerId.isNotEmpty ? selectedStadium.ownerId : uid,
        startTime: startTime,
        endTime: endTime,
        bookingType: BookingType.personal,
        playerTeamName: isAr ? 'حجز تليفوني سريع' : 'Quick Phone Booking',
        isPrivate: true,
        rentBall: false,
        totalPrice: selectedStadium.pricePerHour,
        paymentMethod: 'cash',
        paymentTransactionId: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
        isPaid: false,
      );

      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
      final created = await bookingProvider.createBooking(draft, uid);
      if (created != null && context.mounted) {
        VSPFeedback.showSuccess(
          context,
          isAr ? 'تم تثبيت الحجز التليفوني السريع بنجاح.' : 'Quick phone booking confirmed successfully.',
        );
        onQuickBookingDone();
      }
    }
  }
}
