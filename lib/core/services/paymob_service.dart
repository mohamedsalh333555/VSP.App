import 'dart:async';
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
    required String userPhone,
    String? integrationId,
    bool isTournamentPayment = false,
  }) async {
    try {
      final activeIntegration = int.tryParse(integrationId ?? AppConfig.paymobCardIntegrationId) ?? 5772488;

      final response = await Supabase.instance.client.functions.invoke(
        'create_paymob_intention',
        body: {
          'booking_id': bookingId,
          'is_tournament_payment': isTournamentPayment,
          'amount_egp': amountInEgp,
          'user_email': userEmail,
          'user_name': userName,
          'user_phone': userPhone,
          'integration_id': activeIntegration,
        },
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : (response.data is String ? null : null);

        if (data != null && data['checkout_url'] != null) {
          final checkoutUrl = data['checkout_url'] as String;
          debugPrint('✅ Secure Server-Generated Paymob Checkout URL: $checkoutUrl');
          return checkoutUrl;
        }
      }

      debugPrint('❌ Failed to obtain Paymob checkout URL from Edge Function. Status: ${response.status}');
      return null;
    } catch (e) {
      debugPrint('🚨 PaymobService.getCheckoutUrlFromServer Exception: $e');
      // Strict Fail-Closed: any network error or exception returns null
      return null;
    }
  }

  /// Calculate platform service fee in EGP based on official (amount * 0.0475) + 3.0 EGP rule
  static double calculateServiceFee(double baseAmountEgp) {
    if (baseAmountEgp <= 0) return 0.0;
    return double.parse(((baseAmountEgp * 0.0475) + 3.0).toStringAsFixed(2));
  }

  /// Calculate total checkout price including platform fee
  static double calculateTotalAmount(double baseAmountEgp) {
    if (baseAmountEgp <= 0) return 0.0;
    return double.parse((baseAmountEgp + calculateServiceFee(baseAmountEgp)).toStringAsFixed(2));
  }
}
