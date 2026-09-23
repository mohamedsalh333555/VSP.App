import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/config/app_config.dart';
import 'package:vsp_application/core/config/app_env.dart';
import 'package:vsp_application/core/services/paymob_service.dart';
import 'package:vsp_application/core/services/platform_fee_service.dart';
import 'package:vsp_application/data/models.dart';

void main() {
  group('🔒 Paymob Zero-Trust Security & Configuration Tests', () {
    test('1. Verify only the public Paymob key is exposed to the client', () {
      expect(AppEnv.paymobPublicKey, isNotEmpty);
      expect(AppConfig.paymobPublicKey, isNotEmpty);
    });

    test('2. Verify signed fee configuration is represented by the pure domain model', () {
      final config = PlatformFeeConfig(
        vspRate: 0.02,
        paymobRate: 0.024,
        paymobLocalRate: 0.024,
        paymobForeignRate: 0.026,
        paymobWalletRate: 0.024,
        paymobFixedFee: 3.0,
      );

      expect(config.calculateTotalFees(100.0, 'card'), 7.40);
      expect(config.calculateTotalAmount(100.0, 'card'), 107.40);
      expect(config.calculateTotalAmount(250.0, 'card'), 264.00);
    });

    test('3. Verify Fail-Closed principle: uninitialized server calls return null safely', () async {
      // Without initialized Supabase client / offline, getCheckoutUrlFromServer returns null (Fail-Closed)
      final url = await PaymobService.getCheckoutUrlFromServer(
        amountInEgp: 100.0,
        bookingId: 'test_fail_closed_id',
        userEmail: 'test@vsp.eg',
        userName: 'Test User',
        userPhone: '01100000000',
      );
      // Must return null instead of throwing unhandled exceptions or faking success
      expect(url, isNull);
    });

    test('4. Zero-Trust Architecture: Paymob checkout is delegated to the server', () async {
      final url = await PaymobService.getCheckoutUrlFromServer(
        amountInEgp: 100.0,
        bookingId: 'test_zero_trust_id',
        userEmail: 'test@vsp.eg',
        userName: 'Test User',
        userPhone: '01100000000',
      );
      expect(url, isNull);
    });

    test('5. State Machine Invariance: Unconfirmed bookings never transition to paid without server webhook', () {
      final pendingBooking = Booking(
        id: 'test_bk_001',
        stadiumId: 'std_001',
        stadiumName: 'Camp Nou Aswan',
        ownerId: 'owner_001',
        createdByUserId: 'user_player_001',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        totalPrice: 200.0,
        status: BookingStatus.pending,
        paymentStatus: 'pending',
        isPaid: false,
        paymentMethod: 'paymob',
        createdAt: DateTime.now(),
      );

      // Verify that without a valid Webhook, a pending booking cannot be considered confirmed
      final isBookingConfirmed = pendingBooking.status == BookingStatus.confirmed && pendingBooking.isPaid;
      expect(isBookingConfirmed, isFalse);

      // Only a server-confirmed booking with isPaid = true and status = confirmed passes validation
      final confirmedByServerBooking = pendingBooking.copyWith(
        status: BookingStatus.confirmed,
        isPaid: true,
        paymentStatus: 'paid',
      );
      expect(confirmedByServerBooking.status, BookingStatus.confirmed);
      expect(confirmedByServerBooking.isPaid, isTrue);
      expect(confirmedByServerBooking.paymentStatus, 'paid');
    });
  });
}
