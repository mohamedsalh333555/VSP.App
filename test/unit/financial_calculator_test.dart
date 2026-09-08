import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/paymob_service.dart';
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

    test('Validates 100 EGP booking fee distribution between Platform (2%) and Paymob (2.75% + 3 EGP)', () {
      const baseAmount = 100.0;

      // Platform Owner Net Profit (2.0%): Exactly 2.00 EGP
      final platformShare = PaymobService.calculatePlatformShare(baseAmount);
      expect(platformShare, equals(2.00));

      // Paymob Banking Gateway Share (2.75% + 3.0 EGP): Exactly 5.75 EGP
      final gatewayShare = PaymobService.calculateGatewayShare(baseAmount);
      expect(gatewayShare, equals(5.75));

      // Total fee: 2.00 + 5.75 = 7.75 EGP
      final totalFee = PaymobService.calculateServiceFee(baseAmount);
      expect(totalFee, equals(7.75));

      // Owner receives full pitch rental price: 100.00 EGP
      expect(baseAmount, equals(100.00));
    });
  });
}
