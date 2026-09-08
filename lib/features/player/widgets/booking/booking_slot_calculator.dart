import '../../../../core/utils/app_date_formatter.dart';
import '../../../../data/models.dart';
import 'booking_slot_models.dart';

class BookingSlotCalculator {
  static int _parseTimeToMinutes(String timeStr) {
    return AppDateFormatter.parseTimeToMinutes(timeStr);
  }

  static String _formatMinutesToTime(int totalMinutes, bool isArabic) {
    return AppDateFormatter.formatMinutesToTime(totalMinutes, isArabic);
  }

  static List<TimeSlotItem> generateDynamicTimeSlots({
    required Stadium stadium,
    required bool isArabic,
  }) {
    try {
      final features = stadium.features;
      String startStr = '';
      String endStr = '';

      if (features is Map && features['workingHours'] is Map) {
        startStr = features['workingHours']['start']?.toString() ?? '';
        endStr = features['workingHours']['end']?.toString() ?? '';
      }
      if (startStr.isEmpty) startStr = stadium.openingTime;
      if (endStr.isEmpty) endStr = stadium.closingTime;
      if (startStr.isEmpty) startStr = '04:00 PM';
      if (endStr.isEmpty) endStr = '03:00 AM';

      int startMinutes = _parseTimeToMinutes(startStr);
      int endMinutes = _parseTimeToMinutes(endStr);

      if (endMinutes <= startMinutes) {
        endMinutes += 24 * 60;
      }

      int getCumulativeMinutes(String timeStr) {
        if (timeStr.trim().isEmpty) return -1;
        int min = _parseTimeToMinutes(timeStr);
        if (min < startMinutes) {
          min += 24 * 60;
        }
        return min;
      }

      int? bStart;
      int? bEnd;
      if (features is Map && features['breakTime'] != null) {
        final s = features['breakTime']['start']?.toString() ?? '';
        final e = features['breakTime']['end']?.toString() ?? '';
        if (s.isNotEmpty && e.isNotEmpty) {
          bStart = getCumulativeMinutes(s);
          bEnd = getCumulativeMinutes(e);
        }
      }

      final List<TimeSlotItem> slots = [];
      for (int m = startMinutes; m < endMinutes; m += 30) {
        final slotStart = m;
        final slotEnd = m + 30;

        // Skip slot if it overlaps with stadium break shift
        if (bStart != null && bEnd != null && bStart != -1 && bEnd != -1) {
          if (slotStart < bEnd && slotEnd > bStart) {
            continue;
          }
        }

        final startTimeFormatted = _formatMinutesToTime(slotStart % (24 * 60), isArabic);
        final endTimeFormatted = _formatMinutesToTime(slotEnd % (24 * 60), isArabic);
        final rawKey = _formatMinutesToTime(slotStart % (24 * 60), false);

        slots.add(TimeSlotItem(
          startTime: startTimeFormatted,
          endTime: endTimeFormatted,
          key: rawKey,
          startMinutes: slotStart,
        ));
      }

      return slots;
    } catch (_) {
      return List.generate(8, (i) {
        final m = (14 + i) * 60;
        return TimeSlotItem(
          startTime: _formatMinutesToTime(m, isArabic),
          endTime: _formatMinutesToTime(m + 30, isArabic),
          key: _formatMinutesToTime(m, false),
          startMinutes: m,
        );
      });
    }
  }

  static DateTime getSlotDateTime({
    required String slotKey,
    required Stadium stadium,
    required DateTime selectedDate,
  }) {
    int startMin = _parseTimeToMinutes(slotKey);
    String openStr = stadium.openingTime;
    String closeStr = stadium.closingTime;
    final features = stadium.features;
    if ((openStr.isEmpty || closeStr.isEmpty) && features is Map && features['workingHours'] != null) {
      openStr = openStr.isNotEmpty ? openStr : (features['workingHours']['start'] ?? '');
      closeStr = closeStr.isNotEmpty ? closeStr : (features['workingHours']['end'] ?? '');
    }
    int openMin = _parseTimeToMinutes(openStr);
    int closeMin = _parseTimeToMinutes(closeStr);

    DateTime date = selectedDate;
    final bool isOvernightShift = (closeMin <= openMin && openMin > 0);
    if (isOvernightShift && startMin < openMin) {
      date = date.add(const Duration(days: 1));
    } else if (!isOvernightShift && openMin > 12 * 60 && startMin < openMin) {
      date = date.add(const Duration(days: 1));
    }
    return DateTime(date.year, date.month, date.day, startMin ~/ 60, startMin % 60);
  }

  static bool isSlotBooked({
    required String slotKey,
    required Stadium stadium,
    required DateTime selectedDate,
    required List<Booking> existingBookings,
  }) {
    final slotStartTime = getSlotDateTime(
      slotKey: slotKey,
      stadium: stadium,
      selectedDate: selectedDate,
    ).toUtc();
    final slotEndTime = slotStartTime.add(const Duration(minutes: 30));

    for (var booking in existingBookings) {
      final bStart = booking.startTime.toUtc();
      final bEnd = booking.endTime.toUtc();
      if (slotStartTime.isBefore(bEnd) && slotEndTime.isAfter(bStart)) {
        return true;
      }
    }
    return false;
  }

  static List<String> calculateNewSelectedSlots({
    required String slotKey,
    required List<String> currentSelectedSlots,
    required List<TimeSlotItem> timeSlots,
    required Stadium stadium,
    required DateTime selectedDate,
    required List<Booking> existingBookings,
  }) {
    final selectedTimeSlots = List<String>.from(currentSelectedSlots);
    final isAlreadySelected = selectedTimeSlots.contains(slotKey);
    final idxTapped = timeSlots.indexWhere((s) => s.key == slotKey);

    if (isAlreadySelected) {
      final tappedIdx = selectedTimeSlots.indexOf(slotKey);
      if (selectedTimeSlots.length <= 1) {
        selectedTimeSlots.clear();
      } else if (selectedTimeSlots.length == 2) {
        selectedTimeSlots.remove(slotKey);
      } else {
        if (tappedIdx == 0) {
          selectedTimeSlots.removeAt(0);
        } else if (tappedIdx == selectedTimeSlots.length - 1) {
          selectedTimeSlots.removeLast();
        } else {
          selectedTimeSlots.removeRange(tappedIdx, selectedTimeSlots.length);
        }
      }
      return selectedTimeSlots;
    }

    if (idxTapped == -1) return selectedTimeSlots;

    if (selectedTimeSlots.isEmpty) {
      selectedTimeSlots.add(slotKey);
    } else if (selectedTimeSlots.length == 1) {
      final first = selectedTimeSlots.first;
      final idxFirst = timeSlots.indexWhere((s) => s.key == first);
      if (idxFirst == -1) {
        selectedTimeSlots.clear();
        selectedTimeSlots.add(slotKey);
        return selectedTimeSlots;
      }

      final startIdx = idxFirst < idxTapped ? idxFirst : idxTapped;
      final endIdx = idxFirst > idxTapped ? idxFirst : idxTapped;

      bool hasInvalidSlot = false;
      final List<String> tempRange = [];
      for (int i = startIdx; i <= endIdx; i++) {
        if (i > startIdx) {
          final prevSlot = timeSlots[i - 1];
          final currSlot = timeSlots[i];
          if (currSlot.startMinutes != prevSlot.startMinutes + 30) {
            hasInvalidSlot = true;
            break;
          }
        }
        final checkItem = timeSlots[i];
        final slotDateTime = getSlotDateTime(
          slotKey: checkItem.key,
          stadium: stadium,
          selectedDate: selectedDate,
        );
        final isPast = slotDateTime.isBefore(DateTime.now());
        final isBooked = isSlotBooked(
          slotKey: checkItem.key,
          stadium: stadium,
          selectedDate: selectedDate,
          existingBookings: existingBookings,
        );

        if (isPast || isBooked) {
          hasInvalidSlot = true;
          break;
        }
        tempRange.add(checkItem.key);
      }

      if (hasInvalidSlot) {
        selectedTimeSlots.clear();
        selectedTimeSlots.add(slotKey);
      } else {
        selectedTimeSlots.clear();
        selectedTimeSlots.addAll(tempRange);
      }
    } else {
      selectedTimeSlots.clear();
      selectedTimeSlots.add(slotKey);
    }

    return selectedTimeSlots;
  }
}
