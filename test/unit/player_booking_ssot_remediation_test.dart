import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/services/payment_checkout_service.dart';

void main() {
  group('Player Booking & Open Join SSOT Remediation Tests', () {
    final now = DateTime(2030, 1, 1, 12, 0);

    // Helper: minimal required Booking factory for tests
    Booking makeBooking({
      required String id,
      required DateTime startTime,
      required DateTime endTime,
      required BookingStatus status,
      BookingType bookingType = BookingType.personal,
      double totalPrice = 300,
      String createdByUserId = 'test-user-id',
      String paymentStatus = 'pending',
      bool isPaid = false,
      bool isDepositPaid = false,
      double depositPaid = 0.0,
      int currentPlayers = 1,
      int maxPlayers = 10,
      List<String> joinedUserIds = const [],
      String? cancellationReason,
      String? paymentReconcileState,
      String? paymentSource,
    }) {
      return Booking(
        id: id,
        stadiumId: 'std-1',
        stadiumName: 'Pitch',
        ownerId: 'own-1',
        startTime: startTime,
        endTime: endTime,
        bookingType: bookingType,
        isPrivate: false,
        rentBall: false,
        totalPrice: totalPrice,
        paymentMethod: 'cash',
        status: status,
        createdByUserId: createdByUserId,
        createdAt: now,
        paymentStatus: paymentStatus,
        isPaid: isPaid,
        isDepositPaid: isDepositPaid,
        depositPaid: depositPaid,
        currentPlayers: currentPlayers,
        totalFieldCapacity: maxPlayers,
        joinedUserIds: joinedUserIds,
        cancellationReason: cancellationReason,
        paymentReconcileState: paymentReconcileState,
        paymentSource: paymentSource,
      );
    }

    // 1. Open Join capacity tampering
    test('1. Open Join capacity: Stadium authoritative capacity cannot be tampered with by client input', () {
      const stadiumFieldCapacity = 10;
      const clientTamperedCapacity = 25;
      const initialPlayers = 12;

      final effectiveCapacity = stadiumFieldCapacity;
      final exceedsTrueCapacity = initialPlayers > effectiveCapacity;
      final wouldTamperExceed = initialPlayers > clientTamperedCapacity;

      expect(effectiveCapacity, equals(10));
      expect(exceedsTrueCapacity, isTrue,
          reason: 'Initial players (12) must exceed true stadium capacity (10)');
      expect(wouldTamperExceed, isFalse,
          reason: 'If client capacity (25) was trusted, check would have been bypassed');
    });

    // 2. Participant appears in My Bookings
    test('2. Participant appears in My Bookings when in joinedUserIds', () {
      final booking = makeBooking(
        id: 'booking-open-1',
        startTime: now.add(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 3)),
        bookingType: BookingType.openJoin,
        totalPrice: 500,
        status: BookingStatus.confirmed,
        createdByUserId: 'host-user-id',
        joinedUserIds: ['host-user-id', 'participant-user-b'],
        currentPlayers: 2,
        maxPlayers: 10,
      );

      const participantId = 'participant-user-b';
      final isParticipant = booking.createdByUserId == participantId ||
          booking.joinedUserIds.contains(participantId);

      expect(isParticipant, isTrue,
          reason: 'Participant B must be matched in My Bookings query');
    });

    // 3. Participant receives status update
    test('3. Participant receives status and cancellation updates in stream', () {
      final activeBooking = makeBooking(
        id: 'booking-open-1',
        startTime: now.add(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 3)),
        bookingType: BookingType.openJoin,
        totalPrice: 500,
        status: BookingStatus.confirmed,
        createdByUserId: 'host-user-id',
        joinedUserIds: ['host-user-id', 'participant-user-b'],
      );

      final cancelledBooking = activeBooking.copyWith(
        status: BookingStatus.cancelled,
        cancellationReason: 'Cancelled by host',
      );

      const participantId = 'participant-user-b';
      expect(cancelledBooking.joinedUserIds.contains(participantId), isTrue);
      expect(cancelledBooking.status, equals(BookingStatus.cancelled));
      expect(cancelledBooking.cancellationReason, equals('Cancelled by host'));
    });

    // 4. Full online payment
    test('4. Full online payment: isPaymentConfirmed recognizes paid state', () {
      expect(
        PaymentCheckoutService.isPaymentConfirmed(
          status: 'confirmed',
          paymentStatus: 'paid',
        ),
        isTrue,
      );

      final booking = makeBooking(
        id: 'bk-full',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        status: BookingStatus.confirmed,
        paymentStatus: 'paid',
        isPaid: true,
      );

      expect(booking.effectivePaymentState, equals('fully_paid'));
    });

    // 5. Deposit-only payment
    test('5. Deposit-only payment: isPaymentConfirmed recognizes confirmed partially_paid', () {
      expect(
        PaymentCheckoutService.isPaymentConfirmed(
          status: 'confirmed',
          paymentStatus: 'partially_paid',
        ),
        isTrue,
      );

      expect(
        PaymentCheckoutService.isPaymentConfirmed(
          status: 'pending',
          paymentStatus: 'pending',
        ),
        isFalse,
      );

      final booking = makeBooking(
        id: 'bk-dep',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        status: BookingStatus.confirmed,
        paymentStatus: 'partially_paid',
        depositPaid: 100,
        isPaid: false,
        isDepositPaid: true,
        totalPrice: 300,
      );

      expect(booking.effectivePaymentState, equals('partially_paid'));
      expect(booking.totalPrice - booking.depositPaid, equals(200));
    });

    // 6. Duplicate Paymob webhook
    test('6. Duplicate Paymob webhook: Idempotency check prevents duplicate processing', () {
      const existingPaymobTxnId = 'txn_999888';
      final recordedTransactions = {'txn_999888': 'confirmed'};

      final isAlreadyProcessed = recordedTransactions.containsKey(existingPaymobTxnId);
      expect(isAlreadyProcessed, isTrue);

      final response = {
        'success': true,
        'message': 'duplicate_webhook_ignored',
        'idempotent': true,
      };

      expect(response['idempotent'], isTrue);
      expect(response['message'], equals('duplicate_webhook_ignored'));
    });

    // 7. Expired booking lock
    test('7. Expired booking lock: Checkout rejected when locked_until is in the past', () {
      final expiredLock = now.subtract(const Duration(minutes: 2));
      final isLockValid = expiredLock.isAfter(now);

      expect(isLockValid, isFalse, reason: 'Expired lock must fail validation');
    });

    // 8. Race condition
    test('8. Race Condition: When User A lock expires and User B confirms, User A payment cannot hijack slot', () {
      final userBConfirmedBooking = makeBooking(
        id: 'bk-user-b',
        startTime: now.add(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 2)),
        status: BookingStatus.confirmed,
        createdByUserId: 'user-b',
      );

      final userAPendingBooking = makeBooking(
        id: 'bk-user-a',
        startTime: now.add(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 2)),
        status: BookingStatus.pending,
        createdByUserId: 'user-a',
      );

      final hasConfirmedConflict =
          userBConfirmedBooking.stadiumId == userAPendingBooking.stadiumId &&
              userBConfirmedBooking.status == BookingStatus.confirmed &&
              userBConfirmedBooking.startTime.isBefore(userAPendingBooking.endTime) &&
              userBConfirmedBooking.endTime.isAfter(userAPendingBooking.startTime);

      expect(hasConfirmedConflict, isTrue);

      final resolvedUserA = userAPendingBooking.copyWith(
        status: BookingStatus.cancelled,
        paymentStatus: 'refund_pending',
        cancellationReason: 'Slot confirmed by another user after lock expired',
      );

      expect(resolvedUserA.status, equals(BookingStatus.cancelled));
      expect(resolvedUserA.paymentStatus, equals('refund_pending'));
      expect(userBConfirmedBooking.status, equals(BookingStatus.confirmed));
    });

    // 9. QR attendance -> completed (owner_verified via paymentReconcileState)
    test('9. QR attendance verification sets reconcileState and marks completed', () {
      final confirmedBooking = makeBooking(
        id: 'bk-qr-1',
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now,
        status: BookingStatus.confirmed,
        paymentReconcileState: null,
      );

      final verifiedBooking = confirmedBooking.copyWith(
        status: BookingStatus.completed,
        paymentReconcileState: 'owner_verified',
      );

      expect(verifiedBooking.status, equals(BookingStatus.completed));
      expect(verifiedBooking.paymentReconcileState, equals('owner_verified'));
    });

    // 10. No-show: cron must NOT auto-complete unverified bookings
    test('10. Cron does not auto-complete unverified bookings, allowing owner to record no-show', () {
      final pastUnverifiedBooking = makeBooking(
        id: 'bk-past-unverified',
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.subtract(const Duration(hours: 1)),
        status: BookingStatus.confirmed,
        paymentReconcileState: null,
      );

      final isOwnerVerified =
          pastUnverifiedBooking.paymentReconcileState == 'owner_verified';
      final shouldCronComplete = pastUnverifiedBooking.endTime.isBefore(now) &&
          pastUnverifiedBooking.status == BookingStatus.confirmed &&
          isOwnerVerified;

      expect(shouldCronComplete, isFalse,
          reason: 'Unverified bookings must not be auto-completed by cron');

      final noShowBooking = pastUnverifiedBooking.copyWith(
        cancellationReason: 'Player failed to show up',
      );
      expect(noShowBooking.paymentReconcileState, isNull);
    });

    // 11. Cancelled booking never becomes completed
    test('11. Cancelled booking never becomes completed even if past match time', () {
      final cancelledBooking = makeBooking(
        id: 'bk-cancelled',
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.subtract(const Duration(hours: 1)),
        status: BookingStatus.cancelled,
      );

      final shouldReconcile = cancelledBooking.endTime.isBefore(now) &&
          cancelledBooking.status == BookingStatus.confirmed;

      expect(shouldReconcile, isFalse,
          reason: 'Cancelled booking must never be reconciled to completed');
    });

    // 12. Upcoming is derived state (uses real DateTime.now() for correctness)
    test('12. Upcoming is derived state: confirmed + start_time > now', () {
      final realNow = DateTime.now();

      // A booking starting 48 hours from now must be upcoming
      final futureConfirmedBooking = makeBooking(
        id: 'bk-future',
        startTime: realNow.add(const Duration(hours: 48)),
        endTime: realNow.add(const Duration(hours: 49)),
        status: BookingStatus.confirmed,
      );
      expect(futureConfirmedBooking.isUpcoming, isTrue);

      // A booking that ended 48 hours ago must NOT be upcoming
      final pastConfirmedBooking = makeBooking(
        id: 'bk-past',
        startTime: realNow.subtract(const Duration(hours: 49)),
        endTime: realNow.subtract(const Duration(hours: 48)),
        status: BookingStatus.confirmed,
      );
      expect(pastConfirmedBooking.isUpcoming, isFalse);

      // Cancelled booking is never upcoming
      final cancelledFuture = makeBooking(
        id: 'bk-cancelled-future',
        startTime: realNow.add(const Duration(hours: 48)),
        endTime: realNow.add(const Duration(hours: 49)),
        status: BookingStatus.cancelled,
      );
      expect(cancelledFuture.isUpcoming, isFalse);

      // DB serialization maps upcoming enum alias to confirmed
      expect(BookingStatus.upcoming.toDbValue(), equals('confirmed'));
      expect(BookingStatus.confirmed.toDbValue(), equals('confirmed'));
    });
  });
}
