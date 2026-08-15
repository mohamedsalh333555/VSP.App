import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../config/app_config.dart';

class PaymobService {
  static const String _baseUrl = 'https://accept.paymob.com/api';

  /// 🚀 Generate Paymob Unified Checkout URL using Intention API (Modern Standard)
  static Future<String?> getUnifiedCheckoutUrl({
    required double amountInEgp,
    required String bookingId,
    required String userEmail,
    required String userName,
    required String userPhone,
    String? integrationId,
  }) async {
    try {
      final secretKey = AppConfig.paymobSecretKey;
      final publicKey = AppConfig.paymobPublicKey;
      if (secretKey.isEmpty || publicKey.isEmpty) {
        return null;
      }

      final amountCents = (amountInEgp * 100).round();
      final firstName = userName.trim().isNotEmpty ? userName.trim().split(' ').first : 'Player';
      final lastName = userName.trim().contains(' ') ? userName.trim().split(' ').sublist(1).join(' ') : 'VSP';
      final phone = userPhone.trim().isNotEmpty ? userPhone.trim() : '+201000000000';
      final email = userEmail.trim().isNotEmpty ? userEmail.trim() : 'player@vsp.app';

      final activeIntegration = int.tryParse(integrationId ?? AppConfig.paymobCardIntegrationId) ?? 5772488;

      final response = await http.post(
        Uri.parse('https://accept.paymob.com/v1/intention/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $secretKey',
        },
        body: jsonEncode({
          'amount': amountCents,
          'currency': 'EGP',
          'payment_methods': [activeIntegration],
          'special_reference': '${bookingId}_${DateTime.now().millisecondsSinceEpoch}',
          'billing_data': {
            'first_name': firstName,
            'last_name': lastName,
            'email': email,
            'phone_number': phone,
          }
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final clientSecret = data['client_secret'];
        if (clientSecret != null && clientSecret.toString().isNotEmpty) {
          final checkoutUrl = 'https://accept.paymob.com/unifiedcheckout/?publicKey=$publicKey&clientSecret=$clientSecret&lang=ar';
          debugPrint('✅ Paymob Unified Checkout URL Generated: $checkoutUrl');
          return checkoutUrl;
        }
      }
      debugPrint('⚠️ Paymob Intention Error (${response.statusCode}): ${response.body}');
      return null;
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
    try {
      final apiKey = AppConfig.paymobApiKey;
      if (apiKey.isEmpty) {
        debugPrint('⚠️ Paymob API Key is empty.');
        return null;
      }

      // Step 1: Authentication Token
      final authResponse = await http.post(
        Uri.parse('$_baseUrl/auth/tokens'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'api_key': apiKey}),
      );

      if (authResponse.statusCode != 201 && authResponse.statusCode != 200) {
        debugPrint('❌ Paymob Auth Error (${authResponse.statusCode}): ${authResponse.body}');
        return null;
      }

      final authData = jsonDecode(authResponse.body);
      final String authToken = authData['token'] ?? '';
      if (authToken.isEmpty) {
        debugPrint('❌ Paymob Auth Token empty.');
        return null;
      }

      // Step 2: Order Registration
      final amountCents = (amountInEgp * 100).round();
      final orderResponse = await http.post(
        Uri.parse('$_baseUrl/ecommerce/orders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'auth_token': authToken,
          'delivery_needed': 'false',
          'amount_cents': amountCents.toString(),
          'currency': 'EGP',
          'merchant_order_id': '${bookingId}_${DateTime.now().millisecondsSinceEpoch}',
          'items': [],
        }),
      );

      if (orderResponse.statusCode != 201 && orderResponse.statusCode != 200) {
        debugPrint('❌ Paymob Order Error (${orderResponse.statusCode}): ${orderResponse.body}');
        return null;
      }

      final orderData = jsonDecode(orderResponse.body);
      final dynamic orderId = orderData['id'];
      if (orderId == null) {
        debugPrint('❌ Paymob Order ID null.');
        return null;
      }

      // Step 3: Payment Key Request
      final firstName = userName.trim().isNotEmpty ? userName.trim().split(' ').first : 'Player';
      final lastName = userName.trim().contains(' ') 
          ? userName.trim().split(' ').sublist(1).join(' ') 
          : 'VSP';
      final phone = userPhone.trim().isNotEmpty ? userPhone.trim() : '+201000000000';
      final email = userEmail.trim().isNotEmpty ? userEmail.trim() : 'player@vsp.app';

      // Integration ID: 5772488 (Card Integration) or 5772511 (Wallet Integration)
      final activeIntegrationId = (integrationId != null && integrationId.isNotEmpty) 
          ? integrationId 
          : AppConfig.paymobCardIntegrationId;

      final paymentKeyResponse = await http.post(
        Uri.parse('$_baseUrl/acceptance/payment_keys'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'auth_token': authToken,
          'amount_cents': amountCents.toString(),
          'expiration': 3600,
          'order_id': orderId.toString(),
          'billing_data': {
            'apartment': 'NA',
            'email': email,
            'floor': 'NA',
            'first_name': firstName,
            'street': 'NA',
            'building': 'NA',
            'phone_number': phone,
            'shipping_method': 'PKG',
            'postal_code': 'NA',
            'city': 'Cairo',
            'country': 'EG',
            'last_name': lastName,
            'state': 'Cairo',
          },
          'currency': 'EGP',
          'integration_id': activeIntegrationId,
          'lock_accept_token': 'false',
        }),
      );

      if (paymentKeyResponse.statusCode != 201 && paymentKeyResponse.statusCode != 200) {
        debugPrint('❌ Paymob Payment Key Error (${paymentKeyResponse.statusCode}): ${paymentKeyResponse.body}');
        return null;
      }

      final paymentKeyData = jsonDecode(paymentKeyResponse.body);
      final String paymentToken = paymentKeyData['token'] ?? '';
      if (paymentToken.isNotEmpty) {
        debugPrint('✅ Paymob Payment Token Generated Successfully!');
      }
      return paymentToken.isNotEmpty ? paymentToken : null;
    } catch (e) {
      debugPrint('🚨 PaymobService Exception: $e');
      return null;
    }
  }

  /// 📱 Request Paymob Wallet Redirect URL for Vodafone/Orange/Etisalat Cash
  static Future<String?> getWalletRedirectUrl({
    required String paymentToken,
    required String phone,
  }) async {
    try {
      final cleanPhone = phone.trim().isNotEmpty ? phone.trim() : '01010101010';
      final response = await http.post(
        Uri.parse('$_baseUrl/acceptance/payments/pay'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'source': {
            'identifier': cleanPhone,
            'subtype': 'WALLET',
          },
          'payment_token': paymentToken,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final redirectUrl = data['redirect_url'] ?? data['iframe_redirection_token'];
        if (redirectUrl != null && redirectUrl.toString().isNotEmpty) {
          debugPrint('✅ Paymob Wallet Redirect URL Obtained Successfully!');
          return redirectUrl.toString();
        }
      }
      debugPrint('❌ Paymob Wallet Pay Error (${response.statusCode}): ${response.body}');
      return null;
    } catch (e) {
      debugPrint('🚨 Paymob Wallet Pay Exception: $e');
      return null;
    }
  }

  /// 🔒 Verify Paymob HMAC Signature for Webhooks (Security Audit)
  static bool verifyPaymobHmac(Map<String, dynamic> data, String hmacHeader) {
    try {
      final hmacSecret = AppConfig.paymobHmac;
      if (hmacSecret.isEmpty) return false;

      final obj = data['obj'] as Map<String, dynamic>? ?? data;

      final concatenatedValues = [
        obj['amount_cents'],
        obj['created_at'],
        obj['currency'],
        obj['error_occured'],
        obj['has_parent_transaction'],
        obj['id'],
        obj['integration_id'],
        obj['is_3d_secure'],
        obj['is_auth'],
        obj['is_capture'],
        obj['is_refunded'],
        obj['is_standalone_payment'],
        obj['is_voided'],
        obj['order']?['id'] ?? obj['order'],
        obj['owner'],
        obj['pending'],
        obj['source_data']?['pan'],
        obj['source_data']?['sub_type'],
        obj['source_data']?['type'],
        obj['success'],
      ].map((e) => e?.toString() ?? '').join('');

      final hmac = Hmac(sha512, utf8.encode(hmacSecret));
      final digest = hmac.convert(utf8.encode(concatenatedValues));
      final calculatedHmac = digest.toString();

      return calculatedHmac.toLowerCase() == hmacHeader.toLowerCase();
    } catch (e) {
      debugPrint('⚠️ Error verifying Paymob HMAC: $e');
      return false;
    }
  }
}

