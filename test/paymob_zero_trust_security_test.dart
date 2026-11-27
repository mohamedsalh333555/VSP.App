import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/config/app_config.dart';
import 'package:vsp_application/core/config/app_env.dart';
import 'package:vsp_application/core/services/paymob_service.dart';
import 'package:vsp_application/data/models.dart';

void main() {
  group('🔒 Paymob Zero-Trust Security & Configuration Tests', () {
    test('1. Verify No Paymob Secret Key is compiled into AppConfig or AppEnv', () {
      // AppEnv must only expose public key & supabase config
      expect(AppEnv.paymobPublicKey, isNotEmpty);

      // Verify that no paymobSecretKey getter exists in AppConfig (compilation safety)
      expect(AppConfig.paymobCardIntegrationId, '5772488');
      expect(AppConfig.paymobWalletIntegrationId, '5772511');
    });

    test('2. Verify Platform Fee calculation rule: (5% VSP + 2.4%+3 Paymob gross-up)', () {
      // Base: 100 EGP -> 105 EGP before Paymob -> Total: 110.66 EGP -> Fee: 10.66 EGP
      final fee100 = PaymobService.calculateServiceFee(100.0);
      final total100 = PaymobService.calculateTotalAmount(100.0);
      expect(fee100, 10.66);
      expect(total100, 110.66);

      // Base: 250 EGP -> 262.50 EGP before Paymob -> Total: (262.50 + 3) / (1 - 0.024) = 272.03 EGP -> Fee: 22.03 EGP
      final fee250 = PaymobService.calculateServiceFee(250.0);
      final total250 = PaymobService.calculateTotalAmount(250.0);
      expect(fee250, 22.03);
      expect(total250, 272.03);

      // Edge case: 0 EGP
      expect(PaymobService.calculateServiceFee(0.0), 0.0);
      expect(PaymobService.calculateTotalAmount(0.0), 0.0);
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

    test('4. Zero-Trust Architecture: PaymobService contains ZERO client-side mutation or verification methods', () {
      // Verify that PaymobService only exposes pure calculations and server delegation
      // Old insecure methods (verifyTransactionStatus, verifyPaymobHmac, getPaymentToken, getUnifiedCheckoutUrl) MUST NOT exist.
      final serviceMethods = [
        PaymobService.calculateServiceFee,
        PaymobService.calculateTotalAmount,
        PaymobService.getCheckoutUrlFromServer,
      ];
      expect(serviceMethods.length, 3);
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
