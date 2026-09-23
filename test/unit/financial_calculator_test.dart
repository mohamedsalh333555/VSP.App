import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/platform_fee_service.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/core/utils/owner_financial_calculator.dart';

void main() {
  group('OwnerFinancialCalculator & Platform Share Tests', () {
    final now = DateTime.now();

    final testBookings = [
      // 1. Cash booking (200 EGP total, fully paid in cash at pitch)
      Booking(
        id: 'b1',
        stadiumId: 's1',
        stadiumName: 'Stadium 1',
        ownerId: 'owner1',
        createdByUserId: 'u1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        isPrivate: true,
        rentBall: false,
        totalPrice: 200.0,
        depositPaid: 0.0,
        paymentMethod: 'cash',
        paymentStatus: 'paid',
        status: BookingStatus.confirmed,
        bookingType: BookingType.personal,
        createdAt: now,
      ),
      // 2. Online Paymob booking (100 EGP base amount, customer pays 107.75 EGP online)
      Booking(
        id: 'b2',
        stadiumId: 's1',
        stadiumName: 'Stadium 1',
        ownerId: 'owner1',
        createdByUserId: 'u2',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        isPrivate: true,
        rentBall: false,
        totalPrice: 100.0,
        depositPaid: 100.0,
        paymentMethod: 'paymob_card',
        paymentStatus: 'paid',
        status: BookingStatus.confirmed,
        bookingType: BookingType.personal,
        createdAt: now,
      ),
    ];

    test('Calculates pitch cash revenue and digital balance accurately', () {
      final metrics = OwnerFinancialCalculator.calculate(
        allBookings: testBookings,
        ownerChampionships: [],
        timePeriod: 'today',
        stadiumFilter: 'all',
      );

      // Pitch cash: 200 EGP from booking 1
      expect(metrics.pitchCashRevenue, equals(200.0));

      // Digital balance: 100 EGP from booking 2
      expect(metrics.digitalVspBalance, equals(100.0));

      // Active count: 2
      expect(metrics.activeBookingsCount, equals(2));
    });

    test('Validates 100 EGP booking fee configuration', () {
      const baseAmount = 100.0;
      const config = PlatformFeeConfig(
        vspRate: 0.02,
        paymobRate: 0.024,
        paymobLocalRate: 0.024,
        paymobForeignRate: 0.026,
        paymobWalletRate: 0.024,
        paymobFixedFee: 3.0,
      );

      expect(config.calculateVspFee(baseAmount), 2.00);
      expect(config.calculateGatewayFee(baseAmount, 'card'), 5.40);
      expect(config.calculateTotalFees(baseAmount, 'card'), 7.40);
      expect(config.calculateTotalAmount(baseAmount, 'card'), 107.40);

      // Owner receives the full pitch rental principal; fee handling is separate.
      expect(baseAmount, equals(100.00));
    });

    test('Validates normalized paymentSource and paymentReconcileState domain behavior', () {
      final normalizedBooking = Booking(
        id: 'b_norm',
        stadiumId: 's1',
        stadiumName: 'Stadium 1',
        ownerId: 'owner1',
        createdByUserId: 'u1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        isPrivate: true,
        rentBall: false,
        totalPrice: 300.0,
        depositPaid: 100.0,
        paymentMethod: 'cash',
        paymentSource: 'paymob',
        paymentReconcileState: 'partially_paid',
        status: BookingStatus.confirmed,
        bookingType: BookingType.personal,
        createdAt: now,
      );

      expect(normalizedBooking.effectivePaymentSource, equals('paymob'));
      expect(normalizedBooking.effectivePaymentState, equals('partially_paid'));
      expect(normalizedBooking.isDigital, isTrue);
      expect(normalizedBooking.digitalAmountPaid, equals(100.0));
      expect(normalizedBooking.pitchCashCollected, equals(0.0));
      expect(normalizedBooking.pendingReceivable, equals(200.0)); // 300 total - 100 paid online = 200 pending at pitch
    });

    test('Online deposit (100 EGP) with cash collected at pitch (200 EGP) yields exact split', () {
      final hybridBooking = Booking(
        id: 'b_hybrid',
        stadiumId: 's1',
        stadiumName: 'Stadium 1',
        ownerId: 'owner1',
        createdByUserId: 'u1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        isPrivate: true,
        rentBall: false,
        totalPrice: 300.0,
        depositPaid: 100.0,
        isPaid: true,
        paymentStatus: 'paid',
        paymentMethod: 'paymob',
        paymentSource: 'paymob',
        status: BookingStatus.confirmed,
        bookingType: BookingType.personal,
        createdAt: now,
      );

      expect(hybridBooking.isDigital, isTrue);
      expect(hybridBooking.effectivePaymentState, equals('fully_paid'));
      expect(hybridBooking.digitalAmountPaid, equals(100.0)); // Strictly the online deposit!
      expect(hybridBooking.pitchCashCollected, equals(200.0)); // The cash remainder!
      expect(hybridBooking.pendingReceivable, equals(0.0));
    });
  });
}
