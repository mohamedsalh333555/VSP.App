import '../../../data/models.dart';

/// Categorized user bookings separated into upcoming, pending, and historical buckets.
class CategorizedUserBookings {
  final List<Booking> upcoming;
  final List<Booking> pending;
  final List<Booking> history;

  const CategorizedUserBookings({
    required this.upcoming,
    required this.pending,
    required this.history,
  });
}

/// Categorized owner bookings separated into upcoming and historical buckets.
class CategorizedOwnerBookings {
  final List<Booking> upcoming;
  final List<Booking> history;

  const CategorizedOwnerBookings({
    required this.upcoming,
    required this.history,
  });
}

/// Pure domain helper service for filtering, categorizing, and merging booking lists.
class BookingCategorizationService {
  const BookingCategorizationService._();

  /// Categorizes player bookings into upcoming, pending (recent grace period), and history.
  static CategorizedUserBookings categorizeUserBookings({
    required List<Booking> bookings,
    required DateTime now,
  }) {
    final upcoming = bookings
        .where((b) =>
            (b.status == BookingStatus.confirmed || b.status == BookingStatus.pending) &&
            b.endTime.isAfter(now))
        .toList();

    final tenMinutesAgo = now.subtract(const Duration(minutes: 10));
    final pending = bookings.where((b) {
      final isRecent = b.createdAt.isAfter(tenMinutesAgo);
      final isFuture = b.startTime.isAfter(now);
      final hasConfirmedSameSlot = upcoming.any(
        (u) =>
            u.status == BookingStatus.confirmed &&
            u.stadiumId == b.stadiumId &&
            u.startTime == b.startTime,
      );
      return b.status == BookingStatus.pending && !b.isPaid && isRecent && isFuture && !hasConfirmedSameSlot;
    }).take(1).toList();

    final history = bookings
        .where((b) =>
            b.status == BookingStatus.completed ||
            b.status == BookingStatus.cancelled ||
            (b.status == BookingStatus.confirmed && b.endTime.isBefore(now)))
        .toList();

    return CategorizedUserBookings(
      upcoming: upcoming,
      pending: pending,
      history: history,
    );
  }

  /// Categorizes owner bookings into upcoming and historical lists.
  static CategorizedOwnerBookings categorizeOwnerBookings({
    required List<Booking> bookings,
    required DateTime now,
  }) {
    final upcoming = bookings
        .where((b) => b.status == BookingStatus.confirmed && b.endTime.isAfter(now))
        .toList();

    final history = bookings
        .where((b) =>
            b.status == BookingStatus.completed ||
            b.status == BookingStatus.cancelled ||
            (b.status == BookingStatus.confirmed && b.endTime.isBefore(now)))
        .toList();

    return CategorizedOwnerBookings(
      upcoming: upcoming,
      history: history,
    );
  }

  /// Preserves locally created manual bookings unless cancelled or deleted.
  static List<Booking> mergeLocalManualBookings({
    required List<Booking> incomingBookings,
    required List<Booking> currentBookings,
    required Set<String> cancellingIds,
  }) {
    final result = List<Booking>.from(incomingBookings);
    final manualBookings = currentBookings.where((b) =>
        b.paymentTransactionId?.startsWith('MANUAL') == true &&
        b.status != BookingStatus.cancelled &&
        !cancellingIds.contains(b.id)).toList();

    for (final mb in manualBookings) {
      if (!result.any((b) =>
          b.id == mb.id ||
          (b.startTime.isAtSameMomentAs(mb.startTime) && b.stadiumId == mb.stadiumId))) {
        result.add(mb);
      }
    }
    return result;
  }

  /// Formats and localizes error message for public match actions.
  static String formatPublicMatchError(dynamic error) {
    final errorStr = error.toString();
    if (errorStr.contains('time_conflict')) {
      return 'time_conflict';
    } else if (errorStr.contains('match_is_full')) {
      return 'match_is_full';
    } else if (errorStr.contains('already_joined')) {
      return 'already_joined';
    } else {
      return errorStr.replaceAll('Exception: ', '');
    }
  }
}
