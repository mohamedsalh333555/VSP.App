import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class PaymobService {
  static const String _baseUrl = 'https://accept.paymob.com/api';

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
}
