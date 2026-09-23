import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/booking/booking_creation_coordinator.dart';
import 'package:vsp_application/core/repositories/booking/booking_domain_rules.dart';
import 'package:vsp_application/data/models.dart';

void main() {
  group('BookingCreationCoordinator Tests', () {
    test('dbBookingType mappings match schema expectations', () {
      expect(BookingCreationCoordinator.dbBookingType(BookingType.openJoin), 'open_join');
      expect(BookingCreationCoordinator.dbBookingType(BookingType.challenge), 'challenge');
      expect(BookingCreationCoordinator.dbBookingType(BookingType.team), 'team');
      expect(BookingCreationCoordinator.dbBookingType(BookingType.matchup), 'matchup');
      expect(BookingCreationCoordinator.dbBookingType(BookingType.personal), 'personal');
    });
  });

  group('BookingDomainRules Tests', () {
    test('normalizeManualBookingPayment calculates deposit and full payments', () {
      // Full payment
      final fullPayment = BookingDomainRules.normalizeManualBookingPayment(
        depositPaid: 100,
        totalPrice: 100,
        currentIsPaid: false,
        currentIsDepositPaid: false,
        currentPaymentStatus: 'pending',
      );
      expect(fullPayment.isPaid, isTrue);
      expect(fullPayment.isDepositPaid, isTrue);
      expect(fullPayment.paymentStatus, 'paid');

      // Partial deposit payment
      final depositPayment = BookingDomainRules.normalizeManualBookingPayment(
        depositPaid: 40,
        totalPrice: 100,
        currentIsPaid: false,
        currentIsDepositPaid: false,
        currentPaymentStatus: 'pending',
      );
      expect(depositPayment.isPaid, isFalse);
      expect(depositPayment.isDepositPaid, isTrue);
      expect(depositPayment.paymentStatus, 'deposit_paid');

      // Zero deposit
      final unpaid = BookingDomainRules.normalizeManualBookingPayment(
        depositPaid: 0,
        totalPrice: 100,
        currentIsPaid: false,
        currentIsDepositPaid: false,
        currentPaymentStatus: 'unpaid',
      );
      expect(unpaid.isPaid, isFalse);
      expect(unpaid.isDepositPaid, isFalse);
      expect(unpaid.paymentStatus, 'unpaid');
    });

    test('isPendingBookingExpired respects 8-minute timeout window', () {
      final now = DateTime.now();
      // 5 minutes ago -> not expired
      expect(BookingDomainRules.isPendingBookingExpired(now.subtract(const Duration(minutes: 5)), now), isFalse);
      // 9 minutes ago -> expired
      expect(BookingDomainRules.isPendingBookingExpired(now.subtract(const Duration(minutes: 9)), now), isTrue);
    });

    test('shouldChallengeExpire respects 4-hour creation and 12-hour match windows', () {
      final now = DateTime.now();
      // Created 5 hours ago -> should expire
      expect(
        BookingDomainRules.shouldChallengeExpire(
          createdAt: now.subtract(const Duration(hours: 5)),
          startTime: now.add(const Duration(days: 2)),
          now: now,
        ),
        isTrue,
      );

      // Created 1 hour ago, match starts in 10 hours -> should expire (within 12h)
      expect(
        BookingDomainRules.shouldChallengeExpire(
          createdAt: now.subtract(const Duration(hours: 1)),
          startTime: now.add(const Duration(hours: 10)),
          now: now,
        ),
        isTrue,
      );

      // Created 1 hour ago, match starts in 24 hours -> active
      expect(
        BookingDomainRules.shouldChallengeExpire(
          createdAt: now.subtract(const Duration(hours: 1)),
          startTime: now.add(const Duration(hours: 24)),
          now: now,
        ),
        isFalse,
      );
    });

    test('isResultSubmissionTimeLocked blocks early match submission', () {
      final now = DateTime.now();
      final futureMatchEnd = now.add(const Duration(hours: 1));
      final pastMatchEnd = now.subtract(const Duration(hours: 1));

      expect(BookingDomainRules.isResultSubmissionTimeLocked(futureMatchEnd, now), isTrue);
      expect(BookingDomainRules.isResultSubmissionTimeLocked(pastMatchEnd, now), isFalse);
    });

    test('isBookingVisible filters cancelled and expired pending bookings', () {
      final now = DateTime.now();

      final cancelledBooking = Booking(
        id: '1',
        stadiumId: 's1',
        stadiumName: 'Stadium 1',
        stadiumImageUrl: '',
        ownerId: 'o1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        bookingType: BookingType.personal,
        isPrivate: false,
        rentBall: false,
        totalPrice: 100,
        currency: 'EGP',
        paymentMethod: 'cash',
        status: BookingStatus.cancelled,
        createdByUserId: 'u1',
        createdAt: now.subtract(const Duration(minutes: 10)),
      );

      final expiredPendingBooking = Booking(
        id: '2',
        stadiumId: 's1',
        stadiumName: 'Stadium 1',
        stadiumImageUrl: '',
        ownerId: 'o1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        bookingType: BookingType.personal,
        isPrivate: false,
        rentBall: false,
        totalPrice: 100,
        currency: 'EGP',
        paymentMethod: 'cash',
        status: BookingStatus.pending,
        createdByUserId: 'u1',
        createdAt: now.subtract(const Duration(minutes: 10)),
      );

      final validConfirmedBooking = Booking(
        id: '3',
        stadiumId: 's1',
        stadiumName: 'Stadium 1',
        stadiumImageUrl: '',
        ownerId: 'o1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        bookingType: BookingType.personal,
        isPrivate: false,
        rentBall: false,
        totalPrice: 100,
        currency: 'EGP',
        paymentMethod: 'cash',
        status: BookingStatus.confirmed,
        createdByUserId: 'u1',
        createdAt: now.subtract(const Duration(minutes: 10)),
      );

      expect(BookingDomainRules.isBookingVisible(cancelledBooking, now), isFalse);
      expect(BookingDomainRules.isBookingVisible(expiredPendingBooking, now), isFalse);
      expect(BookingDomainRules.isBookingVisible(validConfirmedBooking, now), isTrue);
    });
  });

}
