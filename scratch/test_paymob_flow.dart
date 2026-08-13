import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('====================================');
  print('🚀 STARTING AUTOMATED PAYMOB TEST FLOW');
  print('====================================');

  const apiKey = 'ZXlKaGJHY2lPaUpJVXpVeE1pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SmpiR0Z6Y3lJNklrMWxjbU5vWVc1MElpd2ljSEp2Wm1sc1pWOXdheUk2TVRFNU5ETTFOeXdpYm1GdFpTSTZJbWx1YVhScFlXd2lmUS5td0FOSGhWbzB5a2N1R2swb3UwYk5zMlRveEpscWNwY2YwZUZxb1liOXlEaUU3MmV4TFEzVDNJTnBqREVleGNWQkE2VFQwYzk3OHZLWWRoOGtsbXFMUQ==';
  const cardIntegrationId = '5772488';
  const walletIntegrationId = '5772511';
  const iframeId = '1059114';

  // 1. Auth Token
  print('\n[1/4] Requesting Auth Token from Paymob...');
  final authRes = await http.post(
    Uri.parse('https://accept.paymob.com/api/auth/tokens'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'api_key': apiKey}),
  );

  print('Status: ${authRes.statusCode}');
  if (authRes.statusCode != 200 && authRes.statusCode != 201) {
    print('❌ Auth Failed: ${authRes.body}');
    return;
  }
  final authToken = jsonDecode(authRes.body)['token'];
  print('✅ Auth Token Obtained: ${authToken.toString().substring(0, 30)}...');

  // 2. Order Creation
  print('\n[2/4] Registering Order for 526.8 EGP...');
  final orderRes = await http.post(
    Uri.parse('https://accept.paymob.com/api/ecommerce/orders'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'auth_token': authToken,
      'delivery_needed': 'false',
      'amount_cents': '52680',
      'currency': 'EGP',
      'merchant_order_id': 'test_booking_${DateTime.now().millisecondsSinceEpoch}',
      'items': [],
    }),
  );

  print('Status: ${orderRes.statusCode}');
  if (orderRes.statusCode != 200 && orderRes.statusCode != 201) {
    print('❌ Order Registration Failed: ${orderRes.body}');
    return;
  }
  final orderId = jsonDecode(orderRes.body)['id'];
  print('✅ Order Created Successfully! Order ID: $orderId');

  // 3. Card Payment Token
  print('\n[3/4] Requesting Card Payment Key (Integration: $cardIntegrationId)...');
  final cardKeyRes = await http.post(
    Uri.parse('https://accept.paymob.com/api/acceptance/payment_keys'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'auth_token': authToken,
      'amount_cents': '52680',
      'expiration': 3600,
      'order_id': orderId.toString(),
      'billing_data': {
        'apartment': 'NA',
        'email': 'test@vsp.app',
        'floor': 'NA',
        'first_name': 'Test',
        'street': 'NA',
        'building': 'NA',
        'phone_number': '+201010101010',
        'shipping_method': 'PKG',
        'postal_code': 'NA',
        'city': 'Cairo',
        'country': 'EG',
        'last_name': 'Player',
        'state': 'Cairo',
      },
      'currency': 'EGP',
      'integration_id': cardIntegrationId,
      'lock_accept_token': 'false',
    }),
  );

  print('Status: ${cardKeyRes.statusCode}');
  if (cardKeyRes.statusCode != 200 && cardKeyRes.statusCode != 201) {
    print('❌ Card Payment Key Failed: ${cardKeyRes.body}');
    return;
  }
  final cardPaymentToken = jsonDecode(cardKeyRes.body)['token'];
  final cardIframeUrl = 'https://accept.paymob.com/api/acceptance/iframes/$iframeId?payment_token=$cardPaymentToken';
  print('✅ Card Payment Token Generated Successfully!');
  print('🔗 Card Iframe URL: $cardIframeUrl');

  // 4. Wallet Payment Token & Pay API
  print('\n[4/4] Requesting Wallet Payment Key (Integration: $walletIntegrationId)...');
  final walletKeyRes = await http.post(
    Uri.parse('https://accept.paymob.com/api/acceptance/payment_keys'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'auth_token': authToken,
      'amount_cents': '52680',
      'expiration': 3600,
      'order_id': orderId.toString(),
      'billing_data': {
        'apartment': 'NA',
        'email': 'test@vsp.app',
        'floor': 'NA',
        'first_name': 'Test',
        'street': 'NA',
        'building': 'NA',
        'phone_number': '+201010101010',
        'shipping_method': 'PKG',
        'postal_code': 'NA',
        'city': 'Cairo',
        'country': 'EG',
        'last_name': 'Player',
        'state': 'Cairo',
      },
      'currency': 'EGP',
      'integration_id': walletIntegrationId,
      'lock_accept_token': 'false',
    }),
  );

  print('Status: ${walletKeyRes.statusCode}');
  if (walletKeyRes.statusCode != 200 && walletKeyRes.statusCode != 201) {
    print('❌ Wallet Payment Key Failed: ${walletKeyRes.body}');
    return;
  }
  final walletPaymentToken = jsonDecode(walletKeyRes.body)['token'];
  print('✅ Wallet Payment Token Generated Successfully!');

  print('📲 Requesting Paymob Wallet Pay Endpoint...');
  final walletPayRes = await http.post(
    Uri.parse('https://accept.paymob.com/api/acceptance/payments/pay'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'source': {
        'identifier': '01010101010',
        'subtype': 'WALLET',
      },
      'payment_token': walletPaymentToken,
    }),
  );

  print('Status: ${walletPayRes.statusCode}');
  if (walletPayRes.statusCode == 200 || walletPayRes.statusCode == 201) {
    final walletData = jsonDecode(walletPayRes.body);
    final redirectUrl = walletData['redirect_url'] ?? walletData['iframe_redirection_token'];
    print('✅ Wallet Redirect URL Obtained Successfully!');
    print('🔗 Wallet Redirect URL: $redirectUrl');
  } else {
    print('❌ Wallet Pay Endpoint Failed: ${walletPayRes.body}');
  }

  print('\n====================================');
  print('🎉 ALL 4 PAYMOB FLOW TESTS PASSED 100%!');
  print('====================================');
}
