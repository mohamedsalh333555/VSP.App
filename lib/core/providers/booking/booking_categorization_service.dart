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

  static bool _isConfirmedLifecycleStatus(BookingStatus status) =>
      status == BookingStatus.confirmed || status == BookingStatus.upcoming;

  /// A pending booking with money collected must stay visible while the
  /// server resolves its status; a checkout timeout is not proof of failure.
  static bool _needsPaymentReconciliation(Booking booking) {
    final paymentState = booking.paymentStatus?.trim().toLowerCase();
    return booking.isPaid ||
        booking.isDepositPaid ||
        booking.depositPaid > 0 ||
        paymentState == 'paid' ||
        paymentState == 'refund_pending';
  }

  /// Categorizes player bookings into upcoming, pending (recent grace period), and history.
  ///
  /// Returned lists are deterministic: the next actionable booking appears
  /// first, while history is newest first. The input list is never mutated.
  static CategorizedUserBookings categorizeUserBookings({
    required List<Booking> bookings,
    required DateTime now,
  }) {
    final upcoming = bookings
        .where(
          (b) =>
              _isConfirmedLifecycleStatus(b.status) &&
              b.endTime.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final tenMinutesAgo = now.subtract(const Duration(minutes: 10));
    final pending = bookings.where((b) {
      final isFuture = b.endTime.isAfter(now);
      // A confirmed booking can overlap a pending checkout without sharing
      // its exact start time. Ignore the same booking ID when lists are merged.
      final hasConfirmedSameSlot = upcoming.any(
        (u) =>
            u.id != b.id &&
            u.stadiumId == b.stadiumId &&
            u.startTime.isBefore(b.endTime) &&
            u.endTime.isAfter(b.startTime),
      );
      if (hasConfirmedSameSlot || !isFuture) return false;
      if (b.status != BookingStatus.pending) return false;
      // Cash bookings remain pending until owner confirms/collects.
      if (b.isCash) return true;
      // A payment awaiting server reconciliation must remain actionable
      // instead of disappearing when the checkout grace period expires.
      if (_needsPaymentReconciliation(b)) return true;
      // Online unpaid checkouts have a 10-minute payment grace period.
      final isRecent = b.createdAt.isAfter(tenMinutesAgo);
      return isRecent;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final history = bookings.where((b) {
      if (b.status == BookingStatus.completed ||
          b.status == BookingStatus.noShow ||
          b.status == BookingStatus.expired) {
        return true;
      }
      if (_isConfirmedLifecycleStatus(b.status) &&
          !b.endTime.isAfter(now)) {
        return true;
      }
      if (b.status == BookingStatus.pending) {
        // A pending checkout displaced by a distinct confirmed booking
        // belongs in history even if money was already collected: retain the
        // record so reconciliation/refund actions can find it.
        final displaced = upcoming.any(
          (u) => u.id != b.id &&
              u.stadiumId == b.stadiumId &&
              u.startTime.isBefore(b.endTime) &&
              u.endTime.isAfter(b.startTime),
        );
        if (displaced) return true;
        // Paid pending bookings remain actionable until the booking ends;
        // then history retains them for reconciliation.
        if (_needsPaymentReconciliation(b)) {
          return !b.endTime.isAfter(now);
        }
        // Expired payment grace periods should not remain in the active list.
        // Keep these records in history rather than making them disappear.
        if (!b.endTime.isAfter(now)) return true;
        if (!b.isCash && !_needsPaymentReconciliation(b) &&
            !b.createdAt.isAfter(tenMinutesAgo)) {
          return true;
        }
      }
      if (b.status == BookingStatus.cancelled) {
        // Exclude abandoned checkouts where no money was ever paid.
        final isAbandonedCheckout =
            b.cancellationReason == 'Cancelled by user during payment checkout' ||
                (b.cancellationReason
                        ?.toLowerCase()
                        .contains('checkout') ??
                    false);
        final hasPaidMoney = b.depositPaid > 0 ||
            b.isDepositPaid ||
            b.isPaid ||
            b.paymentStatus == 'paid' ||
            b.paymentStatus == 'refunded' ||
            b.paymentStatus == 'refund_pending';
        if (isAbandonedCheckout && !hasPaidMoney) {
          return false;
        }
        return true;
      }
      return false;
    }).toList()
      ..sort((a, b) {
        final byEnd = b.endTime.compareTo(a.endTime);
        if (byEnd != 0) return byEnd;
        return b.createdAt.compareTo(a.createdAt);
      });

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
        .where(
          (b) =>
              (_isConfirmedLifecycleStatus(b.status) ||
                  (b.status == BookingStatus.pending &&
                      (b.isCash || _needsPaymentReconciliation(b)))) &&
              b.endTime.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final history = bookings
        .where(
          (b) =>
              b.status == BookingStatus.completed ||
              b.status == BookingStatus.cancelled ||
              b.status == BookingStatus.noShow ||
              b.status == BookingStatus.expired ||
              !b.endTime.isAfter(now),
        )
        .toList()
      ..sort((a, b) {
        final byEnd = b.endTime.compareTo(a.endTime);
        if (byEnd != 0) return byEnd;
        return b.createdAt.compareTo(a.createdAt);
      });

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
    final manualBookings = currentBookings
        .where(
          (b) =>
              b.paymentTransactionId?.startsWith('MANUAL') == true &&
              b.status != BookingStatus.cancelled &&
              b.status != BookingStatus.expired &&
              !cancellingIds.contains(b.id),
        )
        .toList();

    for (final mb in manualBookings) {
      // The backend may return the same manual booking after synchronization.
      // Do not hide a distinct manual booking merely because its start time
      // matches another booking; overlapping records need explicit resolution.
      if (!result.any((b) => b.id == mb.id)) {
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
