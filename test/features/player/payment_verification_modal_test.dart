import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/payment/payment_verification_modal.dart';

void main() {
  group('PaymentVerificationModal Psychological Reassurance Tests', () {
    testWidgets('Renders 3-step verification modal with Arabic texts', (tester) async {
      bool goToBookingsCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaymentVerificationModal(
              bookingId: 'test_booking_123',
              isArabic: true,
              onGoToBookings: () => goToBookingsCalled = true,
            ),
          ),
        ),
      );

      // Initial active state
      expect(find.text('تأكيد حجز الملعب'), findsOneWidget);
      expect(find.text('استلام تفويض السداد البنكي'), findsOneWidget);
      expect(find.text('تثبيت وحجز الساعة بجدول الملعب'), findsOneWidget);
      expect(find.text('إصدار تذكرة الحجز الرسمية'), findsOneWidget);
      expect(goToBookingsCalled, isFalse);

      // Wait 19 seconds for prolonged wait state to activate
      await tester.pump(const Duration(seconds: 19));

      // After 18s prolonged wait, reassurance and quick actions should appear
      expect(find.text('طلبك قيد المعالجة والتأكيد'), findsOneWidget);
      expect(find.text('متابعة في قائمة حجوزاتي'), findsOneWidget);
      expect(find.text('مساعدة فورية عبر واتساب'), findsOneWidget);

      // Tap Go to Bookings
      await tester.tap(find.text('متابعة في قائمة حجوزاتي'));
      expect(goToBookingsCalled, isTrue);
    });

    testWidgets('Renders English verification modal and transitions smoothly', (tester) async {
      bool goToBookingsCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaymentVerificationModal(
              bookingId: 'test_booking_456',
              isArabic: false,
              onGoToBookings: () => goToBookingsCalled = true,
            ),
          ),
        ),
      );

      // Initial English state
      expect(find.text('Securing Stadium Booking'), findsOneWidget);
      expect(find.text('Bank payment authorized'), findsOneWidget);
      expect(find.text('Locking pitch slot in calendar'), findsOneWidget);
      expect(find.text('Issuing official match pass'), findsOneWidget);

      // Advance clock past 18 seconds
      await tester.pump(const Duration(seconds: 19));

      expect(find.text('Processing Confirmation'), findsOneWidget);
      expect(find.text('Go to My Bookings'), findsOneWidget);
      expect(find.text('WhatsApp Instant Support'), findsOneWidget);

      await tester.tap(find.text('Go to My Bookings'));
      expect(goToBookingsCalled, isTrue);
    });
  });
}
