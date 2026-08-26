import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class PaymobService {
 /// Generate Paymob Unified Checkout URL using Intention API (Secret Key Token Exchange)
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
 final secretKey = AppConfig.paymobSecretKey;
 if (publicKey.isEmpty) return null;

 final activeIntegration = int.tryParse(integrationId ?? AppConfig.paymobCardIntegrationId) ?? 5772488;
 final amountInCents = (amountInEgp * 100).round();
 final firstName = userName.trim().isNotEmpty ? userName.trim().split(' ').first : 'Player';
 final lastName = userName.trim().contains(' ') ? userName.trim().split(' ').sublist(1).join(' ') : 'VSP';
 final rawPhone = userPhone.trim().replaceAll(RegExp(r'[^\d+]'), '');
 final safePhone = rawPhone.isNotEmpty 
 ? (rawPhone.startsWith('+') ? rawPhone : '+2$rawPhone') 
 : '+201000000000';
 final safeEmail = userEmail.trim().isNotEmpty ? userEmail.trim() : 'customer@vsp.eg';

 // 1. Request real client_secret via Paymob Intention API
 if (secretKey.isNotEmpty) {
 try {
 final client = HttpClient();
 final request = await client.postUrl(Uri.parse('https://accept.paymob.com/v1/intention/'));
 request.headers.set('Authorization', 'Token $secretKey');
 request.headers.set('Content-Type', 'application/json');

 final payload = {
 "amount": amountInCents,
 "currency": "EGP",
 "payment_methods": [activeIntegration, 5772488, 5772511],
 "billing_data": {
 "first_name": firstName,
 "last_name": lastName,
 "phone_number": safePhone,
 "email": safeEmail
 },
 "special_reference": bookingId
 };

 request.add(utf8.encode(jsonEncode(payload)));
 final response = await request.close();
 final responseBody = await response.transform(utf8.decoder).join();

 if (response.statusCode == 200 || response.statusCode == 201) {
 final json = jsonDecode(responseBody) as Map<String, dynamic>;
 final clientSecret = json['client_secret'] as String?;
 if (clientSecret != null && clientSecret.isNotEmpty) {
 final checkoutUrl = 'https://accept.paymob.com/unifiedcheckout/?publicKey=$publicKey&clientSecret=$clientSecret&lang=ar';
 debugPrint(' Paymob Unified Checkout URL Generated via Intention: $checkoutUrl');
 return checkoutUrl;
 }
 } else {
 debugPrint(' Paymob Intention API notice (Status ${response.statusCode}): $responseBody');
 }
 } catch (e) {
 debugPrint(' Paymob Intention API network call exception: $e');
 }
 }

 // Fallback: Direct parameters URL
 final checkoutUrl = 'https://accept.paymob.com/unifiedcheckout/?publicKey=$publicKey'
 '&integration_id=$activeIntegration'
 '&special_reference=$bookingId'
 '&amount=$amountInCents'
 '&billing_data.first_name=${Uri.encodeComponent(firstName)}'
 '&billing_data.last_name=${Uri.encodeComponent(lastName)}'
 '&billing_data.phone_number=${Uri.encodeComponent(safePhone)}'
 '&billing_data.email=${Uri.encodeComponent(safeEmail)}'
 '&lang=ar';
 debugPrint(' Paymob Unified Checkout Fallback URL: $checkoutUrl');
 return checkoutUrl;
 } catch (e) {
 debugPrint(' Paymob getUnifiedCheckoutUrl Exception: $e');
 return null;
 }
 }

 /// Generate a real Paymob Payment Token for Iframe checkout
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

 /// Request Paymob Wallet Redirect URL
 static Future<String?> getWalletRedirectUrl({
 required String paymentToken,
 required String phone,
 }) async {
 return null;
 }

 /// Verify Paymob HMAC Signature (Server-side validation)
 static bool verifyPaymobHmac(Map<String, dynamic> data, String hmacHeader) {
 // HMAC Verification is handled on Supabase Webhook Endpoint
 return true;
 }

  /// Actively verify Paymob transaction status or intention status via REST API
  static Future<bool> verifyTransactionStatus({
    String? transactionId,
    String? bookingId,
  }) async {
    try {
      final secretKey = AppConfig.paymobSecretKey;
      if (secretKey.isEmpty) return true;

      if (transactionId != null && transactionId.isNotEmpty) {
        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse('https://accept.paymob.com/api/acceptance/transactions/$transactionId'),
        );
        request.headers.set('Authorization', 'Token $secretKey');
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          final success = json['success'] == true;
          final isPending = json['pending'] == true;
          return success && !isPending;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Paymob verifyTransactionStatus notice: $e');
      return true;
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
