import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/providers/booking_provider.dart';
import 'package:vsp_application/core/repositories/booking/mock_booking_repository.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/owner/widgets/dashboard/owner_quick_cash_card.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar', null);
    await initializeDateFormatting('en', null);
  });

  final now = DateTime(2026, 9, 9, 18, 0);

  final unconfirmedCashBooking = Booking(
    id: 'bk_cash_today_1',
    stadiumId: 'std_cairo_1',
    stadiumName: 'Camp Nou Cairo',
    ownerId: 'own_1',
    createdByUserId: 'player_1',
    hostName: 'Captain Ahmed',
    playerPhone: '01012345678',
    startTime: DateTime(now.year, now.month, now.day, 20, 0),
    endTime: DateTime(now.year, now.month, now.day, 21, 0),
    bookingType: BookingType.personal,
    isPrivate: true,
    rentBall: false,
    totalPrice: 400.0,
    depositPaid: 100.0, // 100 EGP deposit paid online, 300 EGP remaining cash
    status: BookingStatus.confirmed,
    paymentStatus: 'partially_paid',
    isPaid: false,
    paymentMethod: 'cash',
    createdAt: now.subtract(const Duration(hours: 2)),
  );

  final paidBooking = Booking(
    id: 'bk_paid_today_2',
    stadiumId: 'std_cairo_1',
    stadiumName: 'Camp Nou Cairo',
    ownerId: 'own_1',
    createdByUserId: 'player_2',
    hostName: 'Captain Tarek',
    playerPhone: '01099998888',
    startTime: DateTime(now.year, now.month, now.day, 18, 0),
    endTime: DateTime(now.year, now.month, now.day, 19, 0),
    bookingType: BookingType.personal,
    isPrivate: true,
    rentBall: false,
    totalPrice: 300.0,
    depositPaid: 300.0,
    status: BookingStatus.confirmed,
    paymentStatus: 'paid',
    isPaid: true,
    paymentMethod: 'paymob',
    createdAt: now.subtract(const Duration(hours: 3)),
  );

  group('💵 OwnerQuickCashCard Tests', () {
    testWidgets('Renders all settled badge when all today bookings are paid', (tester) async {
      final mockRepo = MockBookingRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BookingProvider>(
            create: (_) => BookingProvider(repository: mockRepo),
            child: Scaffold(
              body: OwnerQuickCashCard(
                allBookings: [paidBooking],
                isArabic: true,
                currentTime: now,
              ),
            ),
          ),
        ),
      );

      expect(find.text('جميع مدفوعات اليوم مؤكدة بالكامل'), findsOneWidget);
    });

    testWidgets('Renders cash collection card with remaining amount and allows 1-tap confirmation', (tester) async {
      final mockRepo = MockBookingRepository();
      final provider = BookingProvider(repository: mockRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BookingProvider>.value(
            value: provider,
            child: Scaffold(
              body: SingleChildScrollView(
                child: OwnerQuickCashCard(
                  allBookings: [unconfirmedCashBooking],
                  isArabic: true,
                  currentTime: now,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify header and counters
      expect(find.text('تحصيل كاش اليوم'), findsOneWidget);
      expect(find.text('Captain Ahmed'), findsOneWidget);
      expect(find.text('300 ج.م'), findsOneWidget); // 400 total - 100 deposit = 300 remaining
      expect(find.text('عربون مدفوع إلكترونياً: 100 ج.م'), findsOneWidget);

      // Verify action buttons
      expect(find.text('تم استلام الكاش'), findsOneWidget);

      // Tap 1-tap confirmation
      await tester.tap(find.text('تم استلام الكاش'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Check receipt prompt bottom sheet
      expect(find.text('تم تأكيد استلام النقدية!'), findsOneWidget);
      expect(find.text('إرسال إيصال عبر واتساب'), findsOneWidget);

      // Dismiss bottom sheet and advance timer for toast cleanup
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
