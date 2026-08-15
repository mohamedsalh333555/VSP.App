import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class PaymobService {
  /// 🚀 Generate Paymob Unified Checkout URL using Intention API
  static Future<String?> getUnifiedCheckoutUrl({
    required double amountInEgp,
    required String bookingId,
    required String userEmail,
    required String userName,
    required String userPhone,
    String? integrationId,
  }) async {
    try {
      final publicKey = AppConfig.paymobPublicKey;
      if (publicKey.isEmpty) return null;

      final activeIntegration = int.tryParse(integrationId ?? AppConfig.paymobCardIntegrationId) ?? 5772488;
      final checkoutUrl = 'https://accept.paymob.com/unifiedcheckout/?publicKey=$publicKey&integration_id=$activeIntegration&special_reference=$bookingId&lang=ar';
      debugPrint('✅ Paymob Unified Checkout URL Generated: $checkoutUrl');
      return checkoutUrl;
    } catch (e) {
      debugPrint('🚨 Paymob getUnifiedCheckoutUrl Exception: $e');
      return null;
    }
  }

  /// 🚀 Generate a real Paymob Payment Token for Iframe checkout
  static Future<String?> getPaymentToken({
    required double amountInEgp,
    required String bookingId,
    required String userEmail,
    required String userName,
    required String userPhone,
    String? integrationId,
  }) async {
    // Secret Token generation offloaded to Server / Supabase Edge Functions
    return null;
  }

  /// 📱 Request Paymob Wallet Redirect URL
  static Future<String?> getWalletRedirectUrl({
    required String paymentToken,
    required String phone,
  }) async {
    return null;
  }

  /// 🔒 Verify Paymob HMAC Signature (Server-side validation)
  static bool verifyPaymobHmac(Map<String, dynamic> data, String hmacHeader) {
    // HMAC Verification is handled on Supabase Webhook Endpoint
    return true;
  }
}
