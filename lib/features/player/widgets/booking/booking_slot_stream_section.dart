import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/services/vsp_time_service.dart';
import '../../../../core/ui/vsp_ui.dart';
import '../../../../data/models.dart';
import 'booking_slot_calculator.dart';
import 'booking_slot_card.dart';
import 'booking_slot_models.dart';

/// Renders the real-time slot grid for [BookingConfirmationScreen].
///
/// Subscribes to the [BookingProvider] stream for the given [stadiumId] and
/// [selectedDate] and maps each [TimeSlotItem] to a [BookingSlotCard],
/// highlighting past, booked, selected, and next-available slots.
class BookingSlotStreamSection extends StatelessWidget {
  final String stadiumId;
  final Stadium stadium;
  final DateTime selectedDate;
  final List<TimeSlotItem> timeSlots;
  final List<String> selectedTimeSlots;

  /// Called when the user taps a slot.
  /// Provides the [slotKey] and the current [existingBookings] list so the
  /// parent state can recompute the selection.
  final void Function(String slotKey, List<Booking> existingBookings) onSlotTap;

  /// Optional callback for the "Retry" button shown in the error state.
  final VoidCallback? onRetry;

  const BookingSlotStreamSection({
    super.key,
    required this.stadiumId,
    required this.stadium,
    required this.selectedDate,
    required this.timeSlots,
    required this.selectedTimeSlots,
    required this.onSlotTap,
    this.onRetry,
  });

  bool _isSlotBooked(String slotKey, List<Booking> existingBookings) {
    return BookingSlotCalculator.isSlotBooked(
      slotKey: slotKey,
      stadium: stadium,
      selectedDate: selectedDate,
      existingBookings: existingBookings,
    );
  }

  DateTime _getSlotDateTime(String slotKey) {
    return BookingSlotCalculator.getSlotDateTime(
      slotKey: slotKey,
      stadium: stadium,
      selectedDate: selectedDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: Provider.of<BookingProvider>(context, listen: false)
          .getBookingsForStadium(stadiumId, selectedDate),
      builder: (context, snapshot) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';

        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return VSPStateView(
            state: VSPUiState.loading,
            title: isArabic ? 'جاري تحميل المواعيد' : 'Loading availability',
            message: isArabic
                ? 'بنحدّث المواعيد المتاحة قبل ما تختار.'
                : 'We are refreshing available slots before you choose.',
          );
        }

        // Fail closed on stream errors, even when stale bookings are cached.
        // Rendering stale availability as selectable could enable double-booking.
        if (snapshot.hasError) {
          return VSPStateView(
            state: VSPUiState.error,
            title: isArabic ? 'تعذر تحميل المواعيد' : 'Could not load availability',
            message: isArabic
                ? 'تعذر التأكد من الحجوزات الحالية. حاول مرة تانية قبل اختيار موعد.'
                : 'Current bookings could not be verified. Retry before choosing a slot.',
            onRetry: onRetry,
          );
        }

        // A completed stream without a verified bookings payload is not proof
        // that the venue has zero bookings. Never offer selectable slots.
        if (!snapshot.hasData) {
          return VSPStateView(
            state: VSPUiState.error,
            title: isArabic ? 'تعذر التحقق من المواعيد' : 'Availability not verified',
            message: isArabic
                ? 'لم تصل بيانات الحجوزات. أعد المحاولة قبل اختيار موعد.'
                : 'Booking data was not received. Retry before choosing a slot.',
            onRetry: onRetry,
          );
        }

        final existingBookings = snapshot.data!;

        if (timeSlots.isEmpty) {
          return VSPStateView(
            state: VSPUiState.empty,
            icon: Iconsax.clock_copy,
            title: isArabic ? 'لا توجد مواعيد متاحة' : 'No available time slots',
            message: isArabic
                ? 'لا توجد فترات حجز محددة لهذا اليوم. جرّب يومًا آخر أو تواصل مع الملعب.'
                : 'No booking time slots are configured for this day. Try another date or contact the venue.',
          );
        }
        final now = VSPTimeService.now;
        final bool isToday = selectedDate.year == now.year &&
            selectedDate.month == now.month &&
            selectedDate.day == now.day;

        // Separate a fully booked day from a day without configured hours,
        // and from one where every slot has already passed.
        final allSlotsBooked = timeSlots.every(
          (slot) => _isSlotBooked(slot.key, existingBookings),
        );
        if (allSlotsBooked) {
          return VSPStateView(
            state: VSPUiState.empty,
            icon: Iconsax.calendar_remove_copy,
            title: isArabic ? 'كل المواعيد محجوزة' : 'All slots are booked',
            message: isArabic
                ? 'مواعيد اليوم محجوزة بالفعل. جرّب تاريخًا آخر.'
                : 'All slots for this date are booked. Try another date.',
          );
        }
        final allSlotsPassed = timeSlots.every(
          (slot) => !_getSlotDateTime(slot.key).isAfter(now),
        );
        if (allSlotsPassed) {
          return VSPStateView(
            state: VSPUiState.empty,
            icon: Iconsax.clock_copy,
            title: isArabic ? 'انتهت مواعيد اليوم' : 'All slots have passed',
            message: isArabic
                ? 'كل مواعيد اليوم أصبحت في الماضي. اختر يومًا آخر.'
                : 'All available times for this date have passed. Choose another day.',
          );
        }

        String? firstUpcomingSlotKey;
        if (isToday) {
          for (final item in timeSlots) {
            final dt = _getSlotDateTime(item.key);
            final booked = _isSlotBooked(item.key, existingBookings);
            if (dt.isAfter(now) && !booked) {
              firstUpcomingSlotKey = item.key;
              break;
            }
          }
        }

        return Column(
          children: List.generate(timeSlots.length, (index) {
            final slotItem = timeSlots[index];
            final isBooked = _isSlotBooked(slotItem.key, existingBookings);
            final isSelected = selectedTimeSlots.contains(slotItem.key);
            final slotDateTime = _getSlotDateTime(slotItem.key);
            final slotEndDateTime = slotDateTime.add(const Duration(minutes: 30));
            final isPast = slotDateTime.isBefore(now);
            final isCurrentOngoing =
                isToday && now.isAfter(slotDateTime) && now.isBefore(slotEndDateTime);
            final isNextAvailable = isToday && slotItem.key == firstUpcomingSlotKey;

            final isOvernightSlot = slotItem.startMinutes >= 1440;
            final bool isFirstOvernightSlot =
                isOvernightSlot && (index == 0 || timeSlots[index - 1].startMinutes < 1440);
            final String nextDayName = isOvernightSlot
                ? DateFormat('EEEE', Localizations.localeOf(context).toString())
                    .format(slotDateTime)
                : '';

            return BookingSlotCard(
              slotItem: slotItem,
              isBooked: isBooked,
              isPast: isPast,
              isSelected: isSelected,
              isCurrentOngoing: isCurrentOngoing,
              isNextAvailable: isNextAvailable,
              isFirstOvernightSlot: isFirstOvernightSlot,
              nextDayName: nextDayName,
              onTap: () => onSlotTap(slotItem.key, existingBookings),
            );
          }),
        );
      },
    );
  }
}
