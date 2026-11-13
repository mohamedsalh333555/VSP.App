import '../../../../data/models.dart';
import 'booking_slot_calculator.dart';

/// Defensive, client-side normalization of incoming route selection.
///
/// The schedule/closure checks are only a preview, not a claim that a slot
/// remains free. The booking server must independently revalidate all
/// availability and block double booking.
final class BookingInitialSelection {
  final DateTime date;
  final List<String> slots;

  const BookingInitialSelection._(this.date, this.slots);

  static BookingInitialSelection resolve({
    required Stadium stadium,
    required DateTime operationalBaseDate,
    required DateTime now,
    DateTime? requestedDate,
    List<String>? requestedSlots,
  }) {
    final firstDay = DateTime(
      operationalBaseDate.year,
      operationalBaseDate.month,
      operationalBaseDate.day,
    );
    final finalMonth = DateTime(firstDay.year, firstDay.month + 3);
    final lastDay = DateTime(finalMonth.year, finalMonth.month + 1, 0);
    final day = requestedDate == null
        ? firstDay
        : DateTime(requestedDate.year, requestedDate.month, requestedDate.day);
    if (day.isBefore(firstDay) || day.isAfter(lastDay)) {
      return BookingInitialSelection._(firstDay, const <String>[]);
    }

    final rawSlots = requestedSlots ?? const <String>[];
    if (rawSlots.isEmpty) {
      return BookingInitialSelection._(day, const <String>[]);
    }

    // A duplicate key or blank slot must not change the displayed total.
    final cleaned = rawSlots.map((value) => value.trim()).toList();
    if (cleaned.any((slot) => slot.isEmpty) ||
        cleaned.toSet().length != cleaned.length) {
      return BookingInitialSelection._(day, const <String>[]);
    }

    try {
      final starts = cleaned.map((slot) =>
          BookingSlotCalculator.getSlotDateTime(
            slotKey: slot,
            stadium: stadium,
            selectedDate: day,
          )).toList();
      if (starts.any((start) => !start.isAfter(now) ||
          BookingSlotCalculator.isVenueSlotClosed(
            stadium: stadium,
            slotStart: start,
            now: now,
          )) ||
          !BookingSlotCalculator.areContiguousHalfHourStarts(starts)) {
        return BookingInitialSelection._(day, const <String>[]);
      }
      // The server still decides whether these slots are free.
      return BookingInitialSelection._(day, List.unmodifiable(cleaned));
    } on FormatException {
      return BookingInitialSelection._(day, const <String>[]);
    } on ArgumentError {
      return BookingInitialSelection._(day, const <String>[]);
    }
  }
}
