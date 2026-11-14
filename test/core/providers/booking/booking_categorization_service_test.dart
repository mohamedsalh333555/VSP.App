import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/providers/booking/booking_categorization_service.dart';
import 'package:vsp_application/data/models.dart';

void main() {
  final now = DateTime.utc(2026, 11, 10, 12);

  Booking booking(
    String id, {
    BookingStatus status = BookingStatus.pending,
    DateTime? createdAt,
    DateTime? start,
    DateTime? end,
    String stadiumId = 'stadium-a',
    String paymentMethod = 'online',
    bool isPaid = false,
    bool isDepositPaid = false,
    double depositPaid = 0,
    String paymentStatus = 'pending',
    String? cancellationReason,
    String? transactionId,
  }) {
    return Booking(
      id: id,
      stadiumId: stadiumId,
      stadiumName: 'Test Stadium',
      ownerId: 'owner-a',
      startTime: start ?? now.add(const Duration(hours: 1)),
      endTime: end ?? now.add(const Duration(hours: 2)),
      bookingType: BookingType.personal,
      isPrivate: true,
      rentBall: false,
      totalPrice: 100,
      paymentMethod: paymentMethod,
      status: status,
      createdByUserId: 'player-a',
      createdAt: createdAt ?? now.subtract(const Duration(minutes: 2)),
      isPaid: isPaid,
      isDepositPaid: isDepositPaid,
      depositPaid: depositPaid,
      paymentStatus: paymentStatus,
      cancellationReason: cancellationReason,
      paymentTransactionId: transactionId,
    );
  }

  List<String> ids(Iterable<Booking> bookings) =>
      bookings.map((b) => b.id).toList();

  group('player booking categorization', () {
    test('recent unpaid checkout is pending, old unpaid checkout is history', () {
      final recent = booking('recent');
      final old = booking('old',
          createdAt: now.subtract(const Duration(minutes: 11)));
      final result = BookingCategorizationService.categorizeUserBookings(
          bookings: [old, recent], now: now);
      expect(ids(result.pending), ['recent']);
      expect(ids(result.history), ['old']);
    });

    test('ten minute grace boundary is excluded', () {
      final atBoundary = booking('boundary',
          createdAt: now.subtract(const Duration(minutes: 10)));
      final result = BookingCategorizationService.categorizeUserBookings(
          bookings: [atBoundary], now: now);
      expect(result.pending, isEmpty);
      expect(ids(result.history), ['boundary']);
    });

    test('paid, deposit and refund pending survive checkout grace', () {
      final old = now.subtract(const Duration(minutes: 30));
      final records = [
        booking('paid', createdAt: old, isPaid: true),
        booking('deposit', createdAt: old, isDepositPaid: true),
        booking('amount', createdAt: old, depositPaid: 25),
        booking('refund', createdAt: old, paymentStatus: ' REFUND_PENDING '),
      ];
      final result = BookingCategorizationService.categorizeUserBookings(
          bookings: records, now: now);
      expect(ids(result.pending), ['paid', 'deposit', 'amount', 'refund']);
      expect(result.history, isEmpty);
    });

    test('pending payment moves to history after booked end', () {
      final paid = booking('paid', isPaid: true,
          start: now.subtract(const Duration(hours: 2)),
          end: now);
      final result = BookingCategorizationService.categorizeUserBookings(
          bookings: [paid], now: now);
      expect(result.pending, isEmpty);
      expect(ids(result.history), ['paid']);
    });

    test('overlapping confirmed booking displaces pending on same stadium', () {
      final confirmed = booking('confirmed', status: BookingStatus.confirmed);
      final displaced = booking('displaced', isPaid: true,
          start: now.add(const Duration(minutes: 90)),
          end: now.add(const Duration(hours: 3)));
      final result = BookingCategorizationService.categorizeUserBookings(
          bookings: [displaced, confirmed], now: now);
      expect(ids(result.upcoming), ['confirmed']);
      expect(result.pending, isEmpty);
      expect(ids(result.history), ['displaced']);
    });

    test('other stadium overlap does not displace pending', () {
      final confirmed = booking('confirmed',
          status: BookingStatus.confirmed, stadiumId: 'stadium-b');
      final pending = booking('pending', isPaid: true);
      final result = BookingCategorizationService.categorizeUserBookings(
          bookings: [confirmed, pending], now: now);
      expect(ids(result.pending), ['pending']);
    });

    test('cancelled unpaid checkout hidden but refunded checkout retained', () {
      const reason = 'Cancelled by user during payment checkout';
      final unpaid = booking('unpaid',
          status: BookingStatus.cancelled, cancellationReason: reason);
      final refunded = booking('refunded',
          status: BookingStatus.cancelled, cancellationReason: reason,
          paymentStatus: ' REFUNDED ');
      final result = BookingCategorizationService.categorizeUserBookings(
          bookings: [unpaid, refunded], now: now);
      expect(ids(result.history), ['refunded']);
    });

    test('equal start times keep a stable order across realtime permutations',
        () {
      final sameSlotB = booking('booking-b', status: BookingStatus.confirmed,
          stadiumId: 'pitch-b');
      final sameSlotA = booking('booking-a', status: BookingStatus.confirmed,
          stadiumId: 'pitch-a');
      final pendingB = booking('pending-b', stadiumId: 'pending-stadium-b');
      final pendingA = booking('pending-a', stadiumId: 'pending-stadium-a');
      final orderOne = BookingCategorizationService.categorizeUserBookings(
        bookings: [sameSlotB, pendingB, sameSlotA, pendingA],
        now: now,
      );
      final orderTwo = BookingCategorizationService.categorizeUserBookings(
        bookings: [pendingA, sameSlotA, pendingB, sameSlotB],
        now: now,
      );
      expect(ids(orderOne.upcoming), ['booking-a', 'booking-b']);
      expect(ids(orderTwo.upcoming), ids(orderOne.upcoming));
      expect(ids(orderOne.pending), ['pending-a', 'pending-b']);
      expect(ids(orderTwo.pending), ids(orderOne.pending));
    });

    test('equal history times sort by booking ID without moving input order',
        () {
      final b = booking('history-b', status: BookingStatus.completed);
      final a = booking('history-a', status: BookingStatus.completed);
      final sorted = BookingCategorizationService.categorizeUserBookings(
        bookings: [b, a], now: now,
      );
      expect(ids(sorted.history), ['history-a', 'history-b']);
      expect(ids([b, a]), ['history-b', 'history-a']);
    });

    test('history ordered newest end first and input is unchanged', () {
      final older = booking('older', status: BookingStatus.completed,
          end: now.subtract(const Duration(days: 2)));
      final newer = booking('newer', status: BookingStatus.cancelled,
          end: now.subtract(const Duration(days: 1)));
      final source = [older, newer];
      final result = BookingCategorizationService.categorizeUserBookings(
          bookings: source, now: now);
      expect(ids(result.history), ['newer', 'older']);
      expect(ids(source), ['older', 'newer']);
    });
  });

  group('owner booking categorization', () {
    test('unpaid online checkout ages out into history', () {
      final recent = booking('recent');
      final old = booking('old',
          createdAt: now.subtract(const Duration(minutes: 11)));
      final result = BookingCategorizationService.categorizeOwnerBookings(
          bookings: [recent, old], now: now);
      expect(ids(result.upcoming), ['recent']);
      expect(ids(result.history), ['old']);
    });

    test('cash and paid pending remain visible beyond grace', () {
      final old = now.subtract(const Duration(hours: 1));
      final records = [
        booking('cash', createdAt: old, paymentMethod: 'cash'),
        booking('paid', createdAt: old, paymentStatus: ' PAID '),
        booking('deposit', createdAt: old, depositPaid: 10),
      ];
      final result = BookingCategorizationService.categorizeOwnerBookings(
          bookings: records, now: now);
      expect(ids(result.upcoming), ['cash', 'paid', 'deposit']);
      expect(result.history, isEmpty);
    });

    test('owner upcoming and history ties remain deterministic', () {
      final b = booking('b', status: BookingStatus.confirmed, stadiumId: 'b');
      final a = booking('a', status: BookingStatus.confirmed, stadiumId: 'a');
      final histB = booking('hist-b', status: BookingStatus.completed);
      final histA = booking('hist-a', status: BookingStatus.completed);
      final result = BookingCategorizationService.categorizeOwnerBookings(
        bookings: [b, histB, a, histA], now: now,
      );
      expect(ids(result.upcoming), ['a', 'b']);
      expect(ids(result.history), ['hist-a', 'hist-b']);
    });

    test('ended pending paid booking is historical', () {
      final paid = booking('paid', isPaid: true,
          start: now.subtract(const Duration(hours: 2)), end: now);
      final result = BookingCategorizationService.categorizeOwnerBookings(
          bookings: [paid], now: now);
      expect(result.upcoming, isEmpty);
      expect(ids(result.history), ['paid']);
    });
  });

  group('local manual booking merge', () {
    test('preserves distinct same-slot manual records and deduplicates IDs', () {
      final first = booking('one', transactionId: 'MANUAL-1');
      final second = booking('two', transactionId: 'MANUAL-2');
      final merged = BookingCategorizationService.mergeLocalManualBookings(
        incomingBookings: [first],
        currentBookings: [first, second],
        cancellingIds: {},
      );
      expect(ids(merged), ['one', 'two']);
    });

    test('does not restore cancelled, expired or cancelling manual records', () {
      final merged = BookingCategorizationService.mergeLocalManualBookings(
        incomingBookings: [],
        currentBookings: [
          booking('cancelled', status: BookingStatus.cancelled,
              transactionId: 'MANUAL-1'),
          booking('expired', status: BookingStatus.expired,
              transactionId: 'MANUAL-2'),
          booking('cancelling', transactionId: 'MANUAL-3'),
        ],
        cancellingIds: {'cancelling'},
      );
      expect(merged, isEmpty);
    });
  });
}
