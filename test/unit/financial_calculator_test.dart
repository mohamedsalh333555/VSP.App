import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/owner/screens/owner_dashboard_screen.dart';

void main() {
  group('OwnerFinancialCalculator Tests', () {
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
      // 2. Online Paymob booking (300 EGP total, 100 EGP digital deposit paid, 200 EGP remaining)
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
        totalPrice: 300.0,
        depositPaid: 100.0,
        paymentMethod: 'paymob_card',
        paymentStatus: 'deposit_paid',
        status: BookingStatus.confirmed,
        bookingType: BookingType.personal,
        createdAt: now,
      ),
    ];

    test('Calculates cash revenue and digital balance accurately', () {
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

      // Pending receivables: 200 EGP from booking 2
      expect(metrics.pendingReceivables, equals(200.0));

      // Total pipeline: 200 + 300 = 500 EGP
      expect(metrics.totalPipeline, equals(500.0));

      // Active count: 2
      expect(metrics.activeBookingsCount, equals(2));
    });
  });
}
