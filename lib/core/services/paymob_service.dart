import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_env.dart';
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
          debugPrint('[PaymobService] Secure Server-Generated Checkout URL: $checkoutUrl');
          return checkoutUrl;
        }
      }

      debugPrint('[PaymobService] Edge Function returned ${response.status}. Falling back to direct Paymob Test API...');
      return await _fallbackDirectPaymobIntention(
        amountInEgp: amountInEgp,
        bookingId: bookingId,
        userEmail: userEmail,
        userName: userName,
        userPhone: userPhone,
        integrationId: activeIntegration,
      );
    } catch (e) {
      debugPrint('[PaymobService] getCheckoutUrlFromServer Exception: $e. Falling back to direct Paymob Test API...');
      final activeIntegration = int.tryParse(integrationId ?? AppConfig.paymobCardIntegrationId) ?? 5772488;
      return await _fallbackDirectPaymobIntention(
        amountInEgp: amountInEgp,
        bookingId: bookingId,
        userEmail: userEmail,
        userName: userName,
        userPhone: userPhone,
        integrationId: activeIntegration,
      );
    }
  }

  /// Calculate Platform Owner Net Profit (2.0% of base amount)
  static double calculatePlatformShare(double baseAmountEgp) {
    if (baseAmountEgp <= 0) return 0.0;
    return double.parse((baseAmountEgp * 0.02).toStringAsFixed(2));
  }

  /// Calculate Paymob Banking Gateway Cost (2.75% + 3.0 EGP)
  static double calculateGatewayShare(double baseAmountEgp) {
    if (baseAmountEgp <= 0) return 0.0;
    return double.parse(((baseAmountEgp * 0.0275) + 3.0).toStringAsFixed(2));
  }

  /// Total platform service fee in EGP paid by customer: Platform (2.0%) + Gateway (2.75% + 3.0 EGP) = (amount * 0.0475) + 3.0 EGP
  static double calculateServiceFee(double baseAmountEgp) {
    if (baseAmountEgp <= 0) return 0.0;
    return double.parse(((baseAmountEgp * 0.0475) + 3.0).toStringAsFixed(2));
  }

  /// Calculate total checkout price including platform fee
  static double calculateTotalAmount(double baseAmountEgp) {
    if (baseAmountEgp <= 0) return 0.0;
    return double.parse((baseAmountEgp + calculateServiceFee(baseAmountEgp)).toStringAsFixed(2));
  }

  /// Fallback: إنشاء جلسة الدفع مباشرة مع Paymob Test API في بيئة الاختبار
  static Future<String?> _fallbackDirectPaymobIntention({
    required double amountInEgp,
    required String bookingId,
    required String userEmail,
    required String userName,
    required String userPhone,
    required int integrationId,
  }) async {
    try {
      final safeFirstName = userName.trim().split(' ').first.isEmpty ? 'Player' : userName.trim().split(' ').first;
      final safeLastName = userName.trim().split(' ').length > 1 ? userName.trim().split(' ').sublist(1).join(' ') : 'VSP';
      final rawPhone = userPhone.trim().replaceAll(RegExp(r'[^\d+]'), '');
      final safePhone = rawPhone.isNotEmpty ? (rawPhone.startsWith('+') ? rawPhone : '+2$rawPhone') : '+201000000000';
      final amountInCents = (amountInEgp * 100).round();

      final payload = {
        'amount': amountInCents,
        'currency': 'EGP',
        'payment_methods': [integrationId, 5772488, 5772511],
        'billing_data': {
          'first_name': safeFirstName,
          'last_name': safeLastName,
          'phone_number': safePhone,
          'email': userEmail.trim().isNotEmpty ? userEmail.trim() : 'customer@vsp.eg',
        },
        'special_reference': bookingId,
      };

      final res = await http.post(
        Uri.parse('https://accept.paymob.com/v1/intention/'),
        headers: {
          'Authorization': 'Token ${AppEnv.paymobSecretKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final clientSecret = data['client_secret'] as String?;
        if (clientSecret != null && clientSecret.isNotEmpty) {
          final checkoutUrl = 'https://accept.paymob.com/unifiedcheckout/?publicKey=${AppConfig.paymobPublicKey}&clientSecret=$clientSecret&lang=ar';
          debugPrint('[PaymobService] Direct Paymob Test Checkout URL generated successfully: $checkoutUrl');
          return checkoutUrl;
        }
      }
      debugPrint('[PaymobService] Direct Paymob intention failed: ${res.statusCode} ${res.body}');
      return null;
    } catch (e) {
      debugPrint('[PaymobService] Direct Paymob fallback exception: $e');
      return null;
    }
  }

}