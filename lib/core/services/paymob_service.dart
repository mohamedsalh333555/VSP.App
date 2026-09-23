import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// Service responsible for Paymob payment calculation and server-side checkout generation.
/// Strictly follows Zero-Trust security principles (No secrets on mobile client).
class PaymobService {
  /// Generate Paymob Unified Checkout URL via secure Supabase Edge Function (create_paymob_intention).
  /// The Secret Key is kept exclusively on the server side.
  /// Returns checkout URL string if successful, or null on failure (Fail-Closed).
  static Future<String?> getCheckoutUrlFromServer({
    required double amountInEgp,
    required String bookingId,
    required String userEmail,
    required String userName,
    required String userPhone
    bool isTournamentPayment = false,
    bool isFullPayment = false,
  }) async {
    try {
      final activeIntegration = int.tryParse(integrationId ?? AppConfig.paymobCardIntegrationId) ?? 5772488;

      final response = await Supabase.instance.client.functions.invoke(
        'create_paymob_intention',
        body: {
          'booking_id': bookingId,
          'is_tournament_payment': isTournamentPayment,
          'is_full_payment': isFullPayment,
          'amount_egp': amountInEgp,
          'user_email': userEmail,
          'user_name': userName,
          'user_phone': userPhone,
        },
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : null;

        if (data != null && data['checkout_url'] != null) {
          final checkoutUrl = data['checkout_url'] as String;
          debugPrint('[PaymobService] Secure Server-Generated Checkout URL: $checkoutUrl');
          return checkoutUrl;
        }
      }

      debugPrint('[PaymobService] Edge Function create_paymob_intention failed with status: ${response.status}. Response: ${response.data}');
      return null;
    } catch (e) {
      debugPrint('[PaymobService] getCheckoutUrlFromServer Exception: $e');
      return null;
    }
  }

}