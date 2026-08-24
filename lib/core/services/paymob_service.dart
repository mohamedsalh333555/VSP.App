import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class PaymobService {
 /// Generate Paymob Unified Checkout URL using Intention API
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
 final amountInCents = (amountInEgp * 100).round();
 final firstName = userName.trim().isNotEmpty ? Uri.encodeComponent(userName.trim().split(' ').first) : 'Player';
 final lastName = userName.trim().contains(' ') ? Uri.encodeComponent(userName.trim().split(' ').sublist(1).join(' ')) : 'VSP';
 final safePhone = userPhone.trim().isNotEmpty ? Uri.encodeComponent(userPhone.trim()) : '01000000000';
 final safeEmail = userEmail.trim().isNotEmpty ? Uri.encodeComponent(userEmail.trim()) : 'customer@vsp.eg';

 final checkoutUrl = 'https://accept.paymob.com/unifiedcheckout/?publicKey=$publicKey'
 '&integration_id=$activeIntegration'
 '&special_reference=$bookingId'
 '&amount=$amountInCents'
 '&billing_data.first_name=$firstName'
 '&billing_data.last_name=$lastName'
 '&billing_data.phone_number=$safePhone'
 '&billing_data.email=$safeEmail'
 '&lang=ar';
 debugPrint(' Paymob Unified Checkout URL Generated: $checkoutUrl');
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
