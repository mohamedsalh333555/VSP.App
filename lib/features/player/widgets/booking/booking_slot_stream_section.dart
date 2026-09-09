import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
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
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: VSPColors.accent, strokeWidth: 2.5),
                  SizedBox(height: 12),
                  Text(
                    'جاري قراءة وتحديث الساعات المتاحة...',
                    style: TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError && (!snapshot.hasData || snapshot.data!.isEmpty)) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.refresh, color: VSPColors.warning, size: 28),
                  const SizedBox(height: 8),
                  const Text(
                    'تعذر التحديث اللحظي، اسحب للأسفل للتحديث',
                    style: TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, color: VSPColors.accent, size: 16),
                    label: const Text(
                      'إعادة المحاولة',
                      style: TextStyle(color: VSPColors.accent, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final existingBookings = snapshot.data ?? [];
        final now = DateTime.now();
        final bool isToday = selectedDate.year == now.year &&
            selectedDate.month == now.month &&
            selectedDate.day == now.day;

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
