import '../../../../core/utils/app_date_formatter.dart';
import '../../../../data/models.dart';
import 'booking_slot_models.dart';

class BookingSlotCalculator {
  /// Reject forged/non-contiguous multi-slot selections before creating a
  /// single booking interval. Compare UTC instants across DST boundaries.
  static bool areContiguousHalfHourStarts(List<DateTime> starts) {
    if (starts.isEmpty) return false;
    final sorted = starts.map((date) => date.toUtc()).toList()..sort();
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].difference(sorted[i - 1]) !=
          const Duration(minutes: 30)) {
        return false;
      }
    }
    return true;
  }

  /// Client-side closing-state preview; the server remains the final
  /// authorization source for booking and may have fresher venue status.
  static bool isVenueSlotClosed({
    required Stadium stadium,
    required DateTime slotStart,
    DateTime? now,
  }) {
    if (stadium.isBlocked) return true;
    final closesAt = stadium.maintenanceUntil;
    if (closesAt == null) return false;
    final current = now ?? DateTime.now();
    return closesAt.isAfter(current) && slotStart.isBefore(closesAt);
  }

  static int _parseTimeToMinutes(String timeStr) {
    return AppDateFormatter.parseTimeToMinutes(timeStr);
  }

  static bool _isValidTime(String value) =>
      AppDateFormatter.tryParseTimeToMinutes(value) != null;

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

      if (!stadium.hasServerOperatingHours && features is Map &&
          features.containsKey('workingHours') &&
          features['workingHours'] != null &&
          features['workingHours'] is! Map) {
        return const <TimeSlotItem>[];
      }
      if (!stadium.hasServerOperatingHours && features is Map && features['workingHours'] is Map) {
        startStr = features['workingHours']['start']?.toString() ?? '';
        endStr = features['workingHours']['end']?.toString() ?? '';
      }
      if (startStr.isEmpty) startStr = stadium.openingTime;
      if (endStr.isEmpty) endStr = stadium.closingTime;
      // Missing hours are not bookable: the server requires explicit
      // opening_time and closing_time and rejects unconfigured schedules.
      if (startStr.isEmpty || endStr.isEmpty) {
        return const <TimeSlotItem>[];
      }
      if (!_isValidTime(startStr) || !_isValidTime(endStr)) {
        return const <TimeSlotItem>[];
      }

      int startMinutes = _parseTimeToMinutes(startStr);
      int endMinutes = _parseTimeToMinutes(endStr);

      if (endMinutes <= startMinutes) {
        endMinutes += 24 * 60;
      }
      // Avoid a 24-hour schedule producing a repeated midnight key. A slot
      // key is a clock time and cannot identify two different calendar days.
      if (endMinutes - startMinutes > 24 * 60) {
        return const <TimeSlotItem>[];
      }

      int getCumulativeMinutes(String timeStr) {
        if (timeStr.trim().isEmpty) return -1;
        final parsed = AppDateFormatter.tryParseTimeToMinutes(timeStr);
        if (parsed == null) return -1;
        int min = parsed;
        if (min < startMinutes) {
          min += 24 * 60;
        }
        return min;
      }

      final breakIntervals = <List<int>>[];
      if (features is Map &&
          features.containsKey('breakTimes') &&
          features['breakTimes'] != null &&
          features['breakTimes'] is! List) {
        return const <TimeSlotItem>[];
      }
      if (features is Map && features['breakTimes'] is List) {
        for (final item in features['breakTimes'] as List) {
          if (item is! Map) return const <TimeSlotItem>[];
          final startText = item['start']?.toString() ?? '';
          final endText = item['end']?.toString() ?? '';
          if (!_isValidTime(startText) || !_isValidTime(endText)) {
            return const <TimeSlotItem>[];
          }
          final start = getCumulativeMinutes(startText);
          final end = getCumulativeMinutes(endText);
          if (start < startMinutes || end > endMinutes || end <= start) {
            return const <TimeSlotItem>[];
          }
          breakIntervals.add([start, end]);
        }
      }

      // Backward compatibility for stadium records saved with the legacy single-break shape.
      if (features is Map &&
          !features.containsKey('breakTimes') &&
          features['breakTime'] is Map) {
        final legacyBreak = features['breakTime'] as Map;
        final startText = legacyBreak['start']?.toString() ?? '';
        final endText = legacyBreak['end']?.toString() ?? '';
        if (!_isValidTime(startText) || !_isValidTime(endText)) {
          return const <TimeSlotItem>[];
        }
        final start = getCumulativeMinutes(startText);
        final end = getCumulativeMinutes(endText);
        if (start < startMinutes || end > endMinutes || end <= start) {
          return const <TimeSlotItem>[];
        }
        breakIntervals.add([start, end]);
      }

      // An explicitly supplied legacy closure must have the expected shape.
      if (features is Map &&
          !features.containsKey('breakTimes') &&
          features.containsKey('breakTime') &&
          features['breakTime'] != null &&
          features['breakTime'] is! Map) {
        return const <TimeSlotItem>[];
      }

      // The server enforces stadiums.is_split_shift and its break_* columns.
      // Include those explicit fields even when legacy feature JSON is absent.
      // Conflicting overlapping feature/server breaks fail closed rather than
      // showing booking slots that may be rejected by the database.
      if (stadium.isSplitShift) {
        final rawStart = stadium.breakStartTime;
        final rawEnd = stadium.breakEndTime;
        if (rawStart == null || rawEnd == null ||
            !_isValidTime(rawStart) || !_isValidTime(rawEnd)) {
          return const <TimeSlotItem>[];
        }
        final serverStart = getCumulativeMinutes(rawStart);
        final serverEnd = getCumulativeMinutes(rawEnd);
        if (serverStart < startMinutes || serverEnd > endMinutes ||
            serverEnd <= serverStart) {
          return const <TimeSlotItem>[];
        }
        if (!breakIntervals.any(
          (interval) => interval[0] == serverStart && interval[1] == serverEnd,
        )) {
          breakIntervals.add([serverStart, serverEnd]);
        }
      }

      // Treat overlapping closures as invalid schedule data, not partial availability.
      breakIntervals.sort((a, b) => a[0].compareTo(b[0]));
      for (var i = 1; i < breakIntervals.length; i++) {
        if (breakIntervals[i][0] < breakIntervals[i - 1][1]) {
          return const <TimeSlotItem>[];
        }
      }

      final List<TimeSlotItem> slots = [];
      for (int m = startMinutes; m + 30 <= endMinutes; m += 30) {
        final slotStart = m;
        final slotEnd = m + 30;

        // Exclude every 30-minute slot that overlaps any configured stadium break.
        final overlapsBreak = breakIntervals.any(
          (interval) => slotStart < interval[1] && slotEnd > interval[0],
        );
        if (overlapsBreak) continue;

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
      // Never fabricate booking times when stadium operating-hour data is invalid.
      // An empty schedule is safer than offering impossible slots.
      return const <TimeSlotItem>[];
    }
  }

  static DateTime getSlotDateTime({
    required String slotKey,
    required Stadium stadium,
    required DateTime selectedDate,
  }) {
    // The shared time parser works at minute precision. Reject non-zero
    // seconds in an incoming slot key instead of silently rounding them down
    // to an otherwise valid 30-minute booking boundary.
    final secondsMatch = RegExp(r'^\s*\d{1,2}:\d{1,2}:([0-5]\d)(?:\s|$)')
        .firstMatch(slotKey);
    if (secondsMatch != null && secondsMatch.group(1) != '00') {
      throw FormatException('Booking slot must start at an exact minute');
    }
    final parsedSlot = AppDateFormatter.tryParseTimeToMinutes(slotKey);
    if (parsedSlot == null) {
      throw FormatException('Invalid booking slot time');
    }
    final startMin = parsedSlot;
    String openStr = '';
    String closeStr = '';
    final features = stadium.features;
    if (!stadium.hasServerOperatingHours && features is Map &&
        features.containsKey('workingHours') &&
        features['workingHours'] != null &&
        features['workingHours'] is! Map) {
      throw FormatException('Invalid stadium working hours');
    }
    if (!stadium.hasServerOperatingHours && features is Map && features['workingHours'] is Map) {
      openStr = features['workingHours']['start']?.toString() ?? '';
      closeStr = features['workingHours']['end']?.toString() ?? '';
    }
    if (openStr.isEmpty) openStr = stadium.openingTime;
    if (closeStr.isEmpty) closeStr = stadium.closingTime;
    // Match the schedule generator and server: missing hours fail closed
    // instead of presenting fabricated 4 PM–3 AM booking availability.
    if (openStr.isEmpty || closeStr.isEmpty) {
      throw FormatException('Incomplete stadium working hours');
    }
    if (!_isValidTime(openStr) || !_isValidTime(closeStr)) {
      throw FormatException('Invalid stadium working hours');
    }
    final openMin = _parseTimeToMinutes(openStr);
    final closeMin = _parseTimeToMinutes(closeStr);
    final overnight = closeMin <= openMin;
    final normalizedSlot = overnight && startMin < openMin
        ? startMin + 24 * 60
        : startMin;
    final normalizedClose = overnight ? closeMin + 24 * 60 : closeMin;
    if (normalizedSlot < openMin || normalizedSlot + 30 > normalizedClose) {
      throw FormatException('Booking slot outside stadium operating hours');
    }
    // The caller may supply a stale or forged slot key. Apply the same
    // closure/break validation used by the schedule generator rather than
    // accepting every time inside the outer opening-hours interval.
    final availableSlots = generateDynamicTimeSlots(
      stadium: stadium,
      isArabic: false,
    );
    if (!availableSlots.any((slot) =>
        AppDateFormatter.tryParseTimeToMinutes(slot.key) == startMin)) {
      throw FormatException('Booking slot is not available in stadium schedule');
    }

    // Construct the next *calendar* day rather than adding 24 elapsed hours:
    // Egypt daylight-saving transitions can make a local day 23 or 25 hours.
    final nextDay = overnight && startMin < openMin ? 1 : 0;
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day + nextDay,
      startMin ~/ 60,
      startMin % 60,
    );
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
      if (booking.stadiumId != stadium.id ||
          booking.status == BookingStatus.cancelled ||
          booking.status == BookingStatus.expired) {
        continue;
      }
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
    // Revalidate previously selected slots against the latest availability
    // snapshot before processing another tap. A booking or closure may have
    // appeared since the user first selected the time.
    final selectedTimeSlots = <String>[];
    for (final key in currentSelectedSlots) {
      if (!timeSlots.any((slot) => slot.key == key)) continue;
      try {
        final start = getSlotDateTime(
          slotKey: key,
          stadium: stadium,
          selectedDate: selectedDate,
        );
        if (!start.isBefore(DateTime.now()) &&
            !isVenueSlotClosed(stadium: stadium, slotStart: start) &&
            !isSlotBooked(
              slotKey: key,
              stadium: stadium,
              selectedDate: selectedDate,
              existingBookings: existingBookings,
            )) {
          selectedTimeSlots.add(key);
        }
      } on FormatException {
        // A stale or malformed slot must not survive a schedule refresh.
      }
    }
    final isAlreadySelected = selectedTimeSlots.contains(slotKey);
    final idxTapped = timeSlots.indexWhere((s) => s.key == slotKey);

    // A new selection must never bypass the same availability checks used
    // when extending a multi-slot booking.
    if (!isAlreadySelected && idxTapped >= 0) {
      try {
        final tappedTime = getSlotDateTime(
          slotKey: slotKey,
          stadium: stadium,
          selectedDate: selectedDate,
        );
        if (tappedTime.isBefore(DateTime.now()) ||
            isVenueSlotClosed(stadium: stadium, slotStart: tappedTime) ||
            isSlotBooked(
              slotKey: slotKey,
              stadium: stadium,
              selectedDate: selectedDate,
              existingBookings: existingBookings,
            )) {
          return selectedTimeSlots;
        }
      } on FormatException {
        return selectedTimeSlots;
      }
    }

    if (isAlreadySelected) {
      if (idxTapped == -1) {
        // The schedule was refreshed; a stale selection cannot be booked.
        return <String>[];
      }
      // Keep selected slots in schedule order before applying edge-removal.
      selectedTimeSlots.removeWhere(
        (key) => !timeSlots.any((slot) => slot.key == key),
      );
      selectedTimeSlots.sort((a, b) {
        final aIndex = timeSlots.indexWhere((slot) => slot.key == a);
        final bIndex = timeSlots.indexWhere((slot) => slot.key == b);
        return aIndex.compareTo(bIndex);
      });
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
          // Tapping a middle slot shortens the range from that slot onward.
          selectedTimeSlots.removeRange(tappedIdx, selectedTimeSlots.length);
        }
      }
      return selectedTimeSlots;
    }

    if (idxTapped == -1) {
      // A schedule refresh can remove the tapped slot or an existing
      // selection. Never keep an unavailable selection alive.
      return selectedTimeSlots
          .where((key) => timeSlots.any((slot) => slot.key == key))
          .toList();
    }

    if (selectedTimeSlots.isEmpty) {
      selectedTimeSlots.add(slotKey);
    } else if (selectedTimeSlots.length == 1) {
      final first = selectedTimeSlots.first;
      final idxFirst = timeSlots.indexWhere((s) => s.key == first);
      if (idxFirst == -1) {
        // A refreshed schedule invalidates the old selection. The tapped slot
        // has already been checked for booking conflicts and past dates.
        return <String>[slotKey];
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
        try {
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
          if (isPast || isBooked ||
              isVenueSlotClosed(stadium: stadium, slotStart: slotDateTime)) {
            hasInvalidSlot = true;
            break;
          }
        } on FormatException {
          hasInvalidSlot = true;
          break;
        }
        tempRange.add(checkItem.key);
      }

      if (!hasInvalidSlot) {
        selectedTimeSlots.clear();
        selectedTimeSlots.addAll(tempRange);
      }
      // Preserve the previous valid selection when a range crosses a booked,
      // expired, unavailable or non-contiguous slot.
    } else {
      // When an existing range is selected, a new tap starts a fresh range.
      selectedTimeSlots.clear();
      selectedTimeSlots.add(slotKey);
    }

    return selectedTimeSlots;
  }
}
