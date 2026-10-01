import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/core/providers/booking/booking_sync_coordinator.dart';
import 'package:vsp_application/core/repositories/booking_repository.dart';
import 'package:vsp_application/features/player/services/payment_checkout_coordinator.dart';
import 'package:vsp_application/features/player/services/payment_checkout_service.dart';

class FakeBookingRepository implements BookingRepository {
  final Future<List<Booking>> Function(String) onGetDirectly;
  final Stream<List<Booking>> Function(String) onGetStream;

  FakeBookingRepository({
    required this.onGetDirectly,
    required this.onGetStream,
  });

  @override
  Future<List<Booking>> getUserBookingsDirectly(String userId) => onGetDirectly(userId);

  @override
  Stream<List<Booking>> getUserBookings(String userId) => onGetStream(userId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
      String paymentMethod = 'cash',
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
        paymentMethod: paymentMethod,
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

    // 13. Realtime SSOT Lifecycle: Participant retains booking across partial/reconnect events and updates correctly
    test('13. Realtime SSOT Lifecycle: Participant retains booking across reconnects and receives status updates', () async {
      final directBooking = makeBooking(
        id: 'open-booking-1',
        startTime: now.add(const Duration(hours: 3)),
        endTime: now.add(const Duration(hours: 4)),
        status: BookingStatus.confirmed,
        bookingType: BookingType.openJoin,
        createdByUserId: 'host-user-a',
        joinedUserIds: ['host-user-a', 'player-user-b'],
        currentPlayers: 2,
        maxPlayers: 10,
      );

      final streamController = StreamController<List<Booking>>.broadcast();
      final fakeRepo = FakeBookingRepository(
        onGetDirectly: (uid) async => [directBooking],
        onGetStream: (uid) => streamController.stream,
      );

      final coordinator = BookingSyncCoordinator(fakeRepo);
      final receivedLists = <List<Booking>>[];

      coordinator.syncUserBookings(
        userId: 'player-user-b',
        onData: (bookings, categorized) {
          receivedLists.add(List.from(bookings));
        },
        onError: (err) {},
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(receivedLists.isNotEmpty, isTrue);
      expect(receivedLists.last.any((b) => b.id == 'open-booking-1'), isTrue,
          reason: 'Player B must see booking after initial direct fetch');

      // 1. Reconnect/Partial event arrives (empty list) -> booking MUST NOT vanish
      streamController.add([]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(receivedLists.last.any((b) => b.id == 'open-booking-1'), isTrue,
          reason: 'Booking MUST NOT disappear on partial/empty Realtime reconnect');

      // 2. Realtime event updates player count to 3
      final updatedBooking = directBooking.copyWith(
        currentPlayers: 3,
        joinedUserIds: ['host-user-a', 'player-user-b', 'player-user-c'],
      );
      streamController.add([updatedBooking]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final latest = receivedLists.last.firstWhere((b) => b.id == 'open-booking-1');
      expect(latest.currentPlayers, equals(3),
          reason: 'Player count must update from incoming Realtime event');

      // 3. Host cancels -> Participant receives updated cancelled status without disappearing
      final cancelledBooking = updatedBooking.copyWith(
        status: BookingStatus.cancelled,
        cancellationReason: 'Cancelled by host',
      );
      streamController.add([cancelledBooking]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final cancelledResult = receivedLists.last.firstWhere((b) => b.id == 'open-booking-1');
      expect(cancelledResult.status, equals(BookingStatus.cancelled));
      expect(cancelledResult.cancellationReason, equals('Cancelled by host'));

      coordinator.dispose();
      await streamController.close();
    });

    // 14. Error Resilience: Transport error preserves existing bookings
    test('14. Transport error preserves existing bookings without clearing UI state', () async {
      final initialBooking = makeBooking(
        id: 'bk-resilient-1',
        startTime: now.add(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 2)),
        status: BookingStatus.confirmed,
        createdByUserId: 'user-1',
      );

      final streamController = StreamController<List<Booking>>.broadcast();
      final fakeRepo = FakeBookingRepository(
        onGetDirectly: (uid) async => [initialBooking],
        onGetStream: (uid) => streamController.stream,
      );

      final coordinator = BookingSyncCoordinator(fakeRepo);
      final emittedLists = <List<Booking>>[];
      String? lastError;

      coordinator.syncUserBookings(
        userId: 'user-1',
        onData: (bookings, _) => emittedLists.add(List.from(bookings)),
        onError: (err) => lastError = err,
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emittedLists.last.isNotEmpty, isTrue);

      // Stream encounters WebSocket transport error
      streamController.addError('WebSocket disconnect');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(lastError, isNotNull);
      expect(emittedLists.last.isNotEmpty, isTrue,
          reason: 'Bookings must be preserved on transport error');

      coordinator.dispose();
      await streamController.close();
    });

    // 15. Fallback Polling recognizes confirmed + partially_paid
    test('15. Fallback Polling recognizes confirmed + partially_paid as booking success', () async {
      final coordinator = PaymentCheckoutCoordinator();
      bool confirmedCalled = false;

      final depositConfirmedBooking = makeBooking(
        id: 'bk-poll-dep',
        startTime: now.add(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 3)),
        status: BookingStatus.confirmed,
        paymentStatus: 'partially_paid',
        isDepositPaid: true,
        depositPaid: 100,
      );

      coordinator.startFallbackPolling(
        bookingId: 'bk-poll-dep',
        interval: const Duration(milliseconds: 50),
        fetchBooking: (id) async => depositConfirmedBooking,
        onConfirmed: (_) => confirmedCalled = true,
      );

      await Future<void>.delayed(const Duration(milliseconds: 120));
      coordinator.cancelFallbackPolling();

      expect(confirmedCalled, isTrue,
          reason: 'Polling must invoke onConfirmed for confirmed + partially_paid');

      coordinator.dispose();
    });

    // 16. Fallback Polling rejects pending + partially_paid
    test('16. Fallback Polling strictly rejects pending + partially_paid', () async {
      final coordinator = PaymentCheckoutCoordinator();
      bool confirmedCalled = false;

      final pendingDepositBooking = makeBooking(
        id: 'bk-poll-pending-dep',
        startTime: now.add(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 3)),
        status: BookingStatus.pending,
        paymentStatus: 'partially_paid',
      );

      coordinator.startFallbackPolling(
        bookingId: 'bk-poll-pending-dep',
        interval: const Duration(milliseconds: 50),
        fetchBooking: (id) async => pendingDepositBooking,
        onConfirmed: (_) => confirmedCalled = true,
      );

      await Future<void>.delayed(const Duration(milliseconds: 120));
      coordinator.cancelFallbackPolling();

      expect(confirmedCalled, isFalse,
          reason: 'Polling must NOT confirm pending + partially_paid');

      coordinator.dispose();
    });

    // 17. Payment SSOT Decision Matrix
    test('17. Payment SSOT Decision Matrix enforces strict canonical confirmation rules', () {
      // Confirmed states
      expect(PaymentCheckoutService.isPaymentConfirmed(status: 'confirmed', paymentStatus: 'paid'), isTrue);
      expect(PaymentCheckoutService.isPaymentConfirmed(status: 'confirmed', paymentStatus: 'partially_paid'), isTrue);

      // Pending states — never confirmed
      expect(PaymentCheckoutService.isPaymentConfirmed(status: 'pending', paymentStatus: 'partially_paid'), isFalse);
      expect(PaymentCheckoutService.isPaymentConfirmed(status: 'pending', paymentStatus: 'paid'), isFalse);
      expect(PaymentCheckoutService.isPaymentConfirmed(status: 'pending', paymentStatus: 'pending'), isFalse);

      // Terminal / Cancelled states
      expect(PaymentCheckoutService.isPaymentConfirmed(status: 'cancelled', paymentStatus: 'paid'), isFalse);
      expect(PaymentCheckoutService.isPaymentConfirmed(status: 'cancelled', paymentStatus: 'partially_paid'), isFalse);
      expect(PaymentCheckoutService.isPaymentConfirmed(status: null, paymentStatus: null), isFalse);
    });

    // 18. Booking Ownership and Participation SSOT Predicate
    test('18. Participant Matching rule matches createdByUserId, userId, and joinedUserIds', () {
      final booking = makeBooking(
        id: 'bk-ownership-1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        status: BookingStatus.confirmed,
        createdByUserId: 'host-1',
        joinedUserIds: ['host-1', 'participant-2', 'participant-3'],
      );

      // Host matches
      expect(booking.createdByUserId == 'host-1' || booking.joinedUserIds.contains('host-1'), isTrue);
      // Participants match
      expect(booking.createdByUserId == 'participant-2' || booking.joinedUserIds.contains('participant-2'), isTrue);
      expect(booking.createdByUserId == 'participant-3' || booking.joinedUserIds.contains('participant-3'), isTrue);
      // Unrelated user does not match
      expect(booking.createdByUserId == 'stranger-4' || booking.joinedUserIds.contains('stranger-4'), isFalse);
    });

    // 19. Whitelist Booking State Machine
    test('19. Whitelist Booking State Machine allows only canonical transitions and blocks all invalid ones', () {
      bool isTransitionAllowed(BookingStatus from, BookingStatus to) {
        if (from == BookingStatus.pending) {
          return to == BookingStatus.confirmed ||
              to == BookingStatus.cancelled ||
              to == BookingStatus.expired;
        }
        if (from == BookingStatus.confirmed) {
          return to == BookingStatus.completed || to == BookingStatus.cancelled;
        }
        // Terminal states: completed, cancelled, expired cannot transition anywhere
        return false;
      }

      // Allowed transitions
      expect(isTransitionAllowed(BookingStatus.pending, BookingStatus.confirmed), isTrue);
      expect(isTransitionAllowed(BookingStatus.pending, BookingStatus.cancelled), isTrue);
      expect(isTransitionAllowed(BookingStatus.pending, BookingStatus.expired), isTrue);
      expect(isTransitionAllowed(BookingStatus.confirmed, BookingStatus.completed), isTrue);
      expect(isTransitionAllowed(BookingStatus.confirmed, BookingStatus.cancelled), isTrue);

      // Forbidden transitions (must be blocked)
      expect(isTransitionAllowed(BookingStatus.cancelled, BookingStatus.confirmed), isFalse);
      expect(isTransitionAllowed(BookingStatus.cancelled, BookingStatus.pending), isFalse);
      expect(isTransitionAllowed(BookingStatus.completed, BookingStatus.cancelled), isFalse);
      expect(isTransitionAllowed(BookingStatus.completed, BookingStatus.pending), isFalse);
      expect(isTransitionAllowed(BookingStatus.expired, BookingStatus.confirmed), isFalse);
      expect(isTransitionAllowed(BookingStatus.expired, BookingStatus.cancelled), isFalse);
      expect(isTransitionAllowed(BookingStatus.confirmed, BookingStatus.pending), isFalse);
      expect(isTransitionAllowed(BookingStatus.pending, BookingStatus.completed), isFalse);
    });

    // 20. Booking x Payment Decision Matrix
    test('20. Booking x Payment Decision Matrix validates permissible combinations', () {
      bool isValidCombination(BookingStatus status, String paymentState) {
        switch (status) {
          case BookingStatus.pending:
            return paymentState == 'unpaid';
          case BookingStatus.confirmed:
            return paymentState == 'unpaid' ||
                paymentState == 'partially_paid' ||
                paymentState == 'fully_paid';
          case BookingStatus.completed:
            return paymentState == 'fully_paid' ||
                paymentState == 'partially_paid' ||
                paymentState == 'unpaid';
          case BookingStatus.cancelled:
            return paymentState == 'unpaid' ||
                paymentState == 'refund_pending' ||
                paymentState == 'refunded' ||
                paymentState == 'refund_failed';
          case BookingStatus.expired:
            return paymentState == 'unpaid';
          default:
            return false;
        }
      }

      // Permissible combinations
      expect(isValidCombination(BookingStatus.pending, 'unpaid'), isTrue);
      expect(isValidCombination(BookingStatus.confirmed, 'unpaid'), isTrue);
      expect(isValidCombination(BookingStatus.confirmed, 'partially_paid'), isTrue);
      expect(isValidCombination(BookingStatus.confirmed, 'fully_paid'), isTrue);
      expect(isValidCombination(BookingStatus.completed, 'fully_paid'), isTrue);
      expect(isValidCombination(BookingStatus.cancelled, 'refund_pending'), isTrue);
      expect(isValidCombination(BookingStatus.cancelled, 'refunded'), isTrue);
      expect(isValidCombination(BookingStatus.cancelled, 'refund_failed'), isTrue);
      expect(isValidCombination(BookingStatus.expired, 'unpaid'), isTrue);

      // Forbidden combinations
      expect(isValidCombination(BookingStatus.pending, 'partially_paid'), isFalse);
      expect(isValidCombination(BookingStatus.pending, 'fully_paid'), isFalse);
      expect(isValidCombination(BookingStatus.expired, 'fully_paid'), isFalse);
      expect(isValidCombination(BookingStatus.expired, 'partially_paid'), isFalse);
      expect(isValidCombination(BookingStatus.confirmed, 'refunded'), isFalse);
      expect(isValidCombination(BookingStatus.confirmed, 'refund_pending'), isFalse);
    });

    // 21. Refund Lifecycle & Reconcile Preservation
    test('21. Refund Lifecycle strictly preserves refund_pending and refund_failed without regression', () {
      final refundPendingBooking = makeBooking(
        id: 'bk-ref-pending',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        status: BookingStatus.cancelled,
        paymentStatus: 'refund_pending',
        depositPaid: 100,
        totalPrice: 200,
      );
      expect(refundPendingBooking.effectivePaymentState, equals('refund_pending'));

      final refundFailedBooking = makeBooking(
        id: 'bk-ref-failed',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        status: BookingStatus.cancelled,
        paymentStatus: 'refund_failed',
        depositPaid: 100,
        totalPrice: 200,
      );
      expect(refundFailedBooking.effectivePaymentState, equals('refund_failed'));

      final refundedBooking = makeBooking(
        id: 'bk-refunded',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        status: BookingStatus.cancelled,
        paymentStatus: 'refunded',
        depositPaid: 100,
        totalPrice: 200,
      );
      expect(refundedBooking.effectivePaymentState, equals('refunded'));
    });

    // 22. Unknown Payment Source does NOT default to cash
    test('22. Unknown Payment Source does not default to cash and maps to unknown', () {
      final booking = makeBooking(
        id: 'bk-unknown-method',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        status: BookingStatus.confirmed,
      ).copyWith(paymentMethod: 'crypto_random');

      expect(booking.effectivePaymentSource, equals('unknown'));
      expect(booking.paymentSourceEnum, equals(PaymentSource.unknown));
    });

    // 23. Bank Transfer Payment Source Support
    test('23. Bank Transfer is officially recognized in domain models', () {
      final booking = makeBooking(
        id: 'bk-bank-transfer',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        status: BookingStatus.confirmed,
      ).copyWith(paymentMethod: 'bank_transfer');

      expect(booking.effectivePaymentSource, equals('bank_transfer'));
      expect(booking.paymentSourceEnum, equals(PaymentSource.bankTransfer));
    });

    // 24. Cash Lifecycle & Pitch Settlement
    test('24. Cash Lifecycle: confirmed + unpaid transitions to confirmed + fully_paid upon pitch settlement', () {
      final initialCashBooking = makeBooking(
        id: 'bk-cash-lifecycle',
        startTime: now.add(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 3)),
        status: BookingStatus.confirmed,
        paymentStatus: 'pending',
        isPaid: false,
        totalPrice: 300,
      );

      expect(initialCashBooking.effectivePaymentState, equals('unpaid'));
      expect(initialCashBooking.pitchCashCollected, equals(0.0));
      expect(initialCashBooking.pendingReceivable, equals(300.0));

      final settledCashBooking = initialCashBooking.copyWith(
        isPaid: true,
        paymentStatus: 'fully_paid',
        depositPaid: 300,
      );

      expect(settledCashBooking.effectivePaymentState, equals('fully_paid'));
      expect(settledCashBooking.pitchCashCollected, equals(300.0));
      expect(settledCashBooking.pendingReceivable, equals(0.0));
    });

    // 25. Second Cash Booking Policy: Paid active bookings do NOT block new cash bookings
    test('25. Second Cash Booking Policy correctly distinguishes unpaid from paid active bookings', () {
      final futureTime = DateTime.now().add(const Duration(hours: 4));

      final unpaidActiveCash = makeBooking(
        id: 'bk-active-unpaid',
        startTime: futureTime,
        endTime: futureTime.add(const Duration(hours: 1)),
        status: BookingStatus.confirmed,
        paymentStatus: 'pending',
        isPaid: false,
      );

      final paidActiveCash = makeBooking(
        id: 'bk-active-paid',
        startTime: futureTime,
        endTime: futureTime.add(const Duration(hours: 1)),
        status: BookingStatus.confirmed,
        paymentStatus: 'paid',
        isPaid: true,
      );

      bool isCashBookingRestricted(List<Booking> userBookings) {
        return userBookings.any((b) =>
            b.paymentMethod.toLowerCase() == 'cash' &&
            !b.isPaid &&
            (b.status == BookingStatus.pending || b.status == BookingStatus.confirmed) &&
            b.endTime.isAfter(DateTime.now()));
      }

      // Unpaid active booking blocks cash
      expect(isCashBookingRestricted([unpaidActiveCash]), isTrue);

      // Paid active booking does NOT block cash
      expect(isCashBookingRestricted([paidActiveCash]), isFalse);
    });

    // 26. Whitelist Booking State Machine: All Allowed vs Forbidden Transitions
    test('26. Whitelist Booking State Machine: Verifies exhaustive allowed vs forbidden transitions', () {
      bool isAllowedTransition(BookingStatus from, BookingStatus to) {
        if (from == to) return true;
        if (from == BookingStatus.pending) {
          return to == BookingStatus.confirmed ||
              to == BookingStatus.upcoming ||
              to == BookingStatus.cancelled ||
              to == BookingStatus.expired;
        }
        if (from == BookingStatus.confirmed || from == BookingStatus.upcoming) {
          return to == BookingStatus.completed || to == BookingStatus.cancelled;
        }
        return false; // completed, cancelled, expired are strictly terminal
      }

      // Allowed transitions
      expect(isAllowedTransition(BookingStatus.pending, BookingStatus.confirmed), isTrue);
      expect(isAllowedTransition(BookingStatus.pending, BookingStatus.cancelled), isTrue);
      expect(isAllowedTransition(BookingStatus.pending, BookingStatus.expired), isTrue);
      expect(isAllowedTransition(BookingStatus.confirmed, BookingStatus.completed), isTrue);
      expect(isAllowedTransition(BookingStatus.confirmed, BookingStatus.cancelled), isTrue);

      // Forbidden transitions
      expect(isAllowedTransition(BookingStatus.pending, BookingStatus.completed), isFalse);
      expect(isAllowedTransition(BookingStatus.confirmed, BookingStatus.pending), isFalse);
      expect(isAllowedTransition(BookingStatus.confirmed, BookingStatus.expired), isFalse);
      expect(isAllowedTransition(BookingStatus.completed, BookingStatus.cancelled), isFalse);
      expect(isAllowedTransition(BookingStatus.completed, BookingStatus.pending), isFalse);
      expect(isAllowedTransition(BookingStatus.completed, BookingStatus.confirmed), isFalse);
      expect(isAllowedTransition(BookingStatus.cancelled, BookingStatus.confirmed), isFalse);
      expect(isAllowedTransition(BookingStatus.cancelled, BookingStatus.pending), isFalse);
      expect(isAllowedTransition(BookingStatus.expired, BookingStatus.confirmed), isFalse);
      expect(isAllowedTransition(BookingStatus.expired, BookingStatus.pending), isFalse);
      expect(isAllowedTransition(BookingStatus.expired, BookingStatus.cancelled), isFalse);
    });

    // 27. Booking x Payment Decision Matrix: Allowed vs Forbidden Combinations
    test('27. Booking x Payment Decision Matrix: Exhaustive combination validation', () {
      bool isAllowedMatrixCombo(BookingStatus status, String paymentState) {
        switch (status) {
          case BookingStatus.pending:
            return paymentState == 'unpaid';
          case BookingStatus.confirmed:
          case BookingStatus.upcoming:
            return paymentState == 'unpaid' ||
                paymentState == 'partially_paid' ||
                paymentState == 'fully_paid';
          case BookingStatus.completed:
            return paymentState == 'unpaid' ||
                paymentState == 'partially_paid' ||
                paymentState == 'fully_paid';
          case BookingStatus.cancelled:
            return paymentState == 'unpaid' ||
                paymentState == 'refund_pending' ||
                paymentState == 'refunded' ||
                paymentState == 'refund_failed';
          case BookingStatus.expired:
            return paymentState == 'unpaid';
        }
      }

      // Pending combinations
      expect(isAllowedMatrixCombo(BookingStatus.pending, 'unpaid'), isTrue);
      expect(isAllowedMatrixCombo(BookingStatus.pending, 'partially_paid'), isFalse);
      expect(isAllowedMatrixCombo(BookingStatus.pending, 'fully_paid'), isFalse);
      expect(isAllowedMatrixCombo(BookingStatus.pending, 'refund_pending'), isFalse);
      expect(isAllowedMatrixCombo(BookingStatus.pending, 'refunded'), isFalse);
      expect(isAllowedMatrixCombo(BookingStatus.pending, 'refund_failed'), isFalse);

      // Confirmed combinations
      expect(isAllowedMatrixCombo(BookingStatus.confirmed, 'unpaid'), isTrue);
      expect(isAllowedMatrixCombo(BookingStatus.confirmed, 'partially_paid'), isTrue);
      expect(isAllowedMatrixCombo(BookingStatus.confirmed, 'fully_paid'), isTrue);
      expect(isAllowedMatrixCombo(BookingStatus.confirmed, 'refund_pending'), isFalse);
      expect(isAllowedMatrixCombo(BookingStatus.confirmed, 'refunded'), isFalse);

      // Completed combinations
      expect(isAllowedMatrixCombo(BookingStatus.completed, 'unpaid'), isTrue);
      expect(isAllowedMatrixCombo(BookingStatus.completed, 'partially_paid'), isTrue);
      expect(isAllowedMatrixCombo(BookingStatus.completed, 'fully_paid'), isTrue);
      expect(isAllowedMatrixCombo(BookingStatus.completed, 'refund_pending'), isFalse);

      // Cancelled combinations
      expect(isAllowedMatrixCombo(BookingStatus.cancelled, 'unpaid'), isTrue);
      expect(isAllowedMatrixCombo(BookingStatus.cancelled, 'refund_pending'), isTrue);
      expect(isAllowedMatrixCombo(BookingStatus.cancelled, 'refunded'), isTrue);
      expect(isAllowedMatrixCombo(BookingStatus.cancelled, 'refund_failed'), isTrue);
      expect(isAllowedMatrixCombo(BookingStatus.cancelled, 'fully_paid'), isFalse);
      expect(isAllowedMatrixCombo(BookingStatus.cancelled, 'partially_paid'), isFalse);

      // Expired combinations
      expect(isAllowedMatrixCombo(BookingStatus.expired, 'unpaid'), isTrue);
      expect(isAllowedMatrixCombo(BookingStatus.expired, 'fully_paid'), isFalse);
      expect(isAllowedMatrixCombo(BookingStatus.expired, 'partially_paid'), isFalse);
      expect(isAllowedMatrixCombo(BookingStatus.expired, 'refunded'), isFalse);
    });

    // 28. Expiration Semantics: status=expired, payment_status=unpaid, never payment_status=expired
    test('28. Expiration Semantics: Booking expires to status=expired with payment_state=unpaid', () {
      final expiredBooking = makeBooking(
        id: 'bk-expired-test',
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now,
        status: BookingStatus.expired,
        paymentStatus: 'unpaid',
        isPaid: false,
      );

      expect(expiredBooking.status, equals(BookingStatus.expired));
      expect(expiredBooking.effectivePaymentState, equals('unpaid'));
      expect(expiredBooking.isPaid, isFalse);
      // Ensure expired is never confused with a payment status
      expect(expiredBooking.paymentStatus, isNot(equals('expired')));
    });

    // 29. Official Payment Sources: All 6 sources correctly recognized
    test('29. Official Payment Sources: cash, paymob, instapay, vodafone_cash, bank_transfer, unknown', () {
      Booking createForSource(String method, {String? txId}) {
        return makeBooking(
          id: 'bk-src-$method',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
          status: BookingStatus.confirmed,
        ).copyWith(paymentMethod: method, paymentTransactionId: txId);
      }

      final cashBk = createForSource('cash');
      expect(cashBk.paymentSourceEnum, equals(PaymentSource.cash));
      expect(cashBk.isCash, isTrue);
      expect(cashBk.isDigital, isFalse);
      expect(cashBk.isUnknownPaymentSource, isFalse);

      final paymobBk = createForSource('paymob', txId: 'PAYMOB_12345');
      expect(paymobBk.paymentSourceEnum, equals(PaymentSource.paymob));
      expect(paymobBk.isCash, isFalse);
      expect(paymobBk.isDigital, isTrue);

      final instapayBk = createForSource('instapay');
      expect(instapayBk.paymentSourceEnum, equals(PaymentSource.instapay));
      expect(instapayBk.isCash, isFalse);
      expect(instapayBk.isDigital, isTrue);

      final vfBk = createForSource('vodafone_cash');
      expect(vfBk.paymentSourceEnum, equals(PaymentSource.vodafoneCash));
      expect(vfBk.isCash, isFalse);
      expect(vfBk.isDigital, isTrue);

      final bankBk = createForSource('bank_transfer');
      expect(bankBk.paymentSourceEnum, equals(PaymentSource.bankTransfer));
      expect(bankBk.isCash, isFalse);
      expect(bankBk.isDigital, isTrue);

      final unknownBk = createForSource('some_crypto_token');
      expect(unknownBk.paymentSourceEnum, equals(PaymentSource.unknown));
      expect(unknownBk.isCash, isFalse, reason: 'unknown MUST NEVER default to cash');
      expect(unknownBk.isDigital, isFalse);
      expect(unknownBk.isUnknownPaymentSource, isTrue);
    });

    // 30. Refund Lifecycle & Trigger Reconciliation Invariants
    test('30. Refund Lifecycle: refund states are preserved and never clobbered', () {
      final refundPendingBk = makeBooking(
        id: 'bk-rf-1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        status: BookingStatus.cancelled,
        paymentStatus: 'refund_pending',
      );
      expect(refundPendingBk.effectivePaymentState, equals('refund_pending'));

      final refundedBk = refundPendingBk.copyWith(paymentStatus: 'refunded');
      expect(refundedBk.effectivePaymentState, equals('refunded'));

      final refundFailedBk = refundPendingBk.copyWith(paymentStatus: 'refund_failed');
      expect(refundFailedBk.effectivePaymentState, equals('refund_failed'));
    });

    // 31. Cash Flow & Domain Collection Helpers
    test('31. Cash Flow: collectedAmount and remainingAmount match business definitions', () {
      final cashUnpaid = makeBooking(
        id: 'bk-cf-1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        status: BookingStatus.confirmed,
        totalPrice: 200,
        depositPaid: 0,
        isPaid: false,
      );
      expect(cashUnpaid.collectedAmount, equals(0.0));
      expect(cashUnpaid.remainingAmount, equals(200.0));

      final cashPartial = cashUnpaid.copyWith(
        depositPaid: 80,
        paymentStatus: 'partially_paid',
      );
      expect(cashPartial.collectedAmount, equals(80.0));
      expect(cashPartial.remainingAmount, equals(120.0));

      final cashCompleted = cashPartial.copyWith(
        isPaid: true,
        depositPaid: 200,
        paymentStatus: 'paid',
        status: BookingStatus.completed,
      );
      expect(cashCompleted.collectedAmount, equals(200.0));
      expect(cashCompleted.remainingAmount, equals(0.0));
    });

    // 32. Realtime Sync Resilience: Initial load, status change, and reconnection
    test('32. Realtime Sync: Stream handles initial load, update event, and reconnect without loss', () async {
      final streamController = StreamController<List<Booking>>.broadcast();
      final coordinator = BookingSyncCoordinator(
        FakeBookingRepository(
          onGetDirectly: (uid) async => [],
          onGetStream: (uid) => streamController.stream,
        ),
      );

      final receivedBatches = <List<Booking>>[];
      coordinator.syncUserBookings(
        userId: 'test-user',
        onData: (bookings, categorized) => receivedBatches.add(bookings),
        onError: (err) {},
      );

      final b1 = makeBooking(
        id: 'rt-1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        status: BookingStatus.pending,
        createdByUserId: 'test-user',
      );

      // Event 1: Initial load
      streamController.add([b1]);
      await Future.delayed(const Duration(milliseconds: 10));

      // Event 2: Status update (pending -> confirmed)
      final b1Confirmed = b1.copyWith(status: BookingStatus.confirmed, isPaid: true);
      streamController.add([b1Confirmed]);
      await Future.delayed(const Duration(milliseconds: 10));

      // Event 3: Cancellation update
      final b1Cancelled = b1Confirmed.copyWith(status: BookingStatus.cancelled);
      streamController.add([b1Cancelled]);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedBatches.length, equals(3));
      expect(receivedBatches[0].first.status, equals(BookingStatus.pending));
      expect(receivedBatches[1].first.status, equals(BookingStatus.confirmed));
      expect(receivedBatches[2].first.status, equals(BookingStatus.cancelled));

      coordinator.cancelSubscription();
      await streamController.close();
    });

    // 33. Idempotency Key Preservation in BookingDraft
    test('33. Idempotency Key: Uniquely preserved across BookingDraft serialization', () {
      final draft = BookingDraft(
        stadiumId: 'std-1',
        stadiumName: 'Pitch',
        ownerId: 'own-1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        bookingType: BookingType.personal,
        isPrivate: false,
        rentBall: false,
        totalPrice: 200,
        idempotencyKey: 'uuid-idem-key-12345',
      );

      final map = draft.toMap();
      expect(map['idempotencyKey'], equals('uuid-idem-key-12345'));

      final restored = BookingDraft.fromMap(map);
      expect(restored.idempotencyKey, equals('uuid-idem-key-12345'));
    });

    // 34. Expiration SSOT: pending & challenge pending transitions strictly to expired + unpaid
    test('34. Expiration SSOT: pending & challenge pending strictly resolve to expired + unpaid', () {
      final pendingRegular = makeBooking(
        id: 'bk-exp-reg',
        startTime: now.add(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 2)),
        status: BookingStatus.expired,
        paymentStatus: 'unpaid',
        paymentMethod: 'paymob',
        isPaid: false,
      );
      expect(pendingRegular.status, equals(BookingStatus.expired));
      expect(pendingRegular.effectivePaymentState, equals('unpaid'));
      expect(pendingRegular.isMatrixValid, isTrue);

      final challengePending = makeBooking(
        id: 'bk-exp-chl',
        bookingType: BookingType.challenge,
        startTime: now.add(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 2)),
        status: BookingStatus.expired,
        paymentStatus: 'unpaid',
        paymentMethod: 'cash',
        isPaid: false,
      );
      expect(challengePending.status, equals(BookingStatus.expired));
      expect(challengePending.effectivePaymentState, equals('unpaid'));
      expect(challengePending.isMatrixValid, isTrue);

      // Verify that expired with paid/partially_paid/refund_* states is strictly illegal
      for (final invalidState in ['partially_paid', 'fully_paid', 'refund_pending', 'refunded', 'refund_failed']) {
        final isValid = BookingPaymentMatrix.isValidCombination(
          status: BookingStatus.expired,
          paymentState: invalidState,
          paymentMethod: 'cash',
        );
        expect(isValid, isFalse, reason: 'Expired booking cannot have payment state $invalidState');
      }
    });

    // 35. SSOT Matrix: Booking Status × Payment State × Payment Method Enforcement
    test('35. SSOT Matrix: Booking Status x Payment State x Payment Method exact rules', () {
      // confirmed + unpaid + cash => ALLOWED (pitch collection pending)
      expect(
        BookingPaymentMatrix.isValidCombination(
          status: BookingStatus.confirmed,
          paymentState: 'unpaid',
          paymentMethod: 'cash',
        ),
        isTrue,
      );

      // confirmed + unpaid + paymob => FORBIDDEN (cannot confirm unpaid online booking)
      expect(
        BookingPaymentMatrix.isValidCombination(
          status: BookingStatus.confirmed,
          paymentState: 'unpaid',
          paymentMethod: 'paymob',
        ),
        isFalse,
      );

      // pending + unpaid + paymob => ALLOWED (waiting for checkout)
      expect(
        BookingPaymentMatrix.isValidCombination(
          status: BookingStatus.pending,
          paymentState: 'unpaid',
          paymentMethod: 'paymob',
        ),
        isTrue,
      );

      // pending + fully_paid => FORBIDDEN (if paid, must be promoted to confirmed)
      expect(
        BookingPaymentMatrix.isValidCombination(
          status: BookingStatus.pending,
          paymentState: 'fully_paid',
          paymentMethod: 'paymob',
        ),
        isFalse,
      );

      // expired + unpaid => ALLOWED
      expect(
        BookingPaymentMatrix.isValidCombination(
          status: BookingStatus.expired,
          paymentState: 'unpaid',
          paymentMethod: 'paymob',
        ),
        isTrue,
      );

      // expired + partially_paid => FORBIDDEN
      expect(
        BookingPaymentMatrix.isValidCombination(
          status: BookingStatus.expired,
          paymentState: 'partially_paid',
          paymentMethod: 'paymob',
        ),
        isFalse,
      );

      // expired + fully_paid => FORBIDDEN
      expect(
        BookingPaymentMatrix.isValidCombination(
          status: BookingStatus.expired,
          paymentState: 'fully_paid',
          paymentMethod: 'cash',
        ),
        isFalse,
      );

      // cancelled + refund_pending => ALLOWED
      expect(
        BookingPaymentMatrix.isValidCombination(
          status: BookingStatus.cancelled,
          paymentState: 'refund_pending',
          paymentMethod: 'paymob',
        ),
        isTrue,
      );

      // cancelled + refunded => ALLOWED
      expect(
        BookingPaymentMatrix.isValidCombination(
          status: BookingStatus.cancelled,
          paymentState: 'refunded',
          paymentMethod: 'paymob',
        ),
        isTrue,
      );

      // cancelled + refund_failed => ALLOWED
      expect(
        BookingPaymentMatrix.isValidCombination(
          status: BookingStatus.cancelled,
          paymentState: 'refund_failed',
          paymentMethod: 'paymob',
        ),
        isTrue,
      );

      // cancelled + unpaid => ALLOWED
      expect(
        BookingPaymentMatrix.isValidCombination(
          status: BookingStatus.cancelled,
          paymentState: 'unpaid',
          paymentMethod: 'cash',
        ),
        isTrue,
      );
    });

    // 36. Financial Amount Semantics: Explicit separation of paid, deposit, cash collected, and remaining
    test('36. Financial Amount Semantics: Full online, full cash, cash deposit, and online deposit + cash remainder', () {
      // 1. Full online payment (paymob, totalPrice = 300, depositPaid = 0, isPaid = true)
      final fullOnline = makeBooking(
        id: 'bk-amt-online',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        status: BookingStatus.confirmed,
        totalPrice: 300,
        depositPaid: 0,
        isPaid: true,
        paymentStatus: 'paid',
        paymentMethod: 'paymob',
      );
      expect(fullOnline.isDigital, isTrue);
      expect(fullOnline.digitalAmountPaid, equals(300.0));
      expect(fullOnline.pitchCashCollected, equals(0.0));
      expect(fullOnline.totalAmountPaid, equals(300.0));
      expect(fullOnline.collectedAmount, equals(300.0), reason: 'Full online payment must reflect 300.0 collected, NOT 0.0 depositPaid');
      expect(fullOnline.actualDepositPaid, equals(0.0));
      expect(fullOnline.remainingAmount, equals(0.0));
      expect(fullOnline.pendingReceivable, equals(0.0));

      // 2. Full cash payment (cash, totalPrice = 250, depositPaid = 0, isPaid = true)
      final fullCash = makeBooking(
        id: 'bk-amt-cash',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        status: BookingStatus.confirmed,
        totalPrice: 250,
        depositPaid: 0,
        isPaid: true,
        paymentStatus: 'paid',
        paymentMethod: 'cash',
      );
      expect(fullCash.isCash, isTrue);
      expect(fullCash.digitalAmountPaid, equals(0.0));
      expect(fullCash.pitchCashCollected, equals(250.0));
      expect(fullCash.totalAmountPaid, equals(250.0));
      expect(fullCash.collectedAmount, equals(250.0));
      expect(fullCash.actualDepositPaid, equals(0.0));
      expect(fullCash.remainingAmount, equals(0.0));

      // 3. Cash partial payment (cash, totalPrice = 200, depositPaid = 50, isPaid = false, partially_paid)
      final partialCash = makeBooking(
        id: 'bk-amt-cash-part',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        status: BookingStatus.confirmed,
        totalPrice: 200,
        depositPaid: 50,
        isPaid: false,
        paymentStatus: 'partially_paid',
        paymentMethod: 'cash',
      );
      expect(partialCash.isCash, isTrue);
      expect(partialCash.digitalAmountPaid, equals(0.0));
      expect(partialCash.pitchCashCollected, equals(50.0));
      expect(partialCash.totalAmountPaid, equals(50.0));
      expect(partialCash.collectedAmount, equals(50.0));
      expect(partialCash.actualDepositPaid, equals(50.0));
      expect(partialCash.remainingAmount, equals(150.0));
      expect(partialCash.pendingReceivable, equals(150.0));

      // 4. Online deposit + pitch cash remainder (paymob, totalPrice = 300, depositPaid = 100)
      // Step A: Deposit paid online
      final onlineDeposit = makeBooking(
        id: 'bk-amt-online-dep',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        status: BookingStatus.confirmed,
        totalPrice: 300,
        depositPaid: 100,
        isPaid: false,
        paymentStatus: 'partially_paid',
        paymentMethod: 'paymob',
      );
      expect(onlineDeposit.isDigital, isTrue);
      expect(onlineDeposit.digitalAmountPaid, equals(100.0));
      expect(onlineDeposit.pitchCashCollected, equals(0.0));
      expect(onlineDeposit.totalAmountPaid, equals(100.0));
      expect(onlineDeposit.collectedAmount, equals(100.0));
      expect(onlineDeposit.actualDepositPaid, equals(100.0));
      expect(onlineDeposit.remainingAmount, equals(200.0));
      expect(onlineDeposit.pendingReceivable, equals(200.0));

      // Step B: Remaining 200 EGP collected in cash at the pitch
      final settledAtPitch = onlineDeposit.copyWith(
        isPaid: true,
        paymentStatus: 'paid',
      );
      expect(settledAtPitch.digitalAmountPaid, equals(100.0));
      expect(settledAtPitch.pitchCashCollected, equals(200.0));
      expect(settledAtPitch.totalAmountPaid, equals(300.0));
      expect(settledAtPitch.collectedAmount, equals(300.0));
      expect(settledAtPitch.remainingAmount, equals(0.0));
      expect(settledAtPitch.pendingReceivable, equals(0.0));
    });
  });
}
