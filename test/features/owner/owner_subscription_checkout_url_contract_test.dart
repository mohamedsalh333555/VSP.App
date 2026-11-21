import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/owner_subscription_repository.dart';

void main() {
  const trusted = 'https://accept.paymob.com/unifiedcheckout/'
      '?publicKey=pk_test_value&clientSecret=secret_test_value&lang=ar';

  test('accepts the exact official destination constructed by our Edge handler', () {
    final parsed = OwnerSubscriptionRepository.trustedPaymobCheckoutUri(trusted);
    expect(parsed, isNotNull);
    expect(parsed!.scheme, 'https');
    expect(parsed.host, 'accept.paymob.com');
    expect(parsed.path, '/unifiedcheckout/');
    expect(parsed.queryParameters['publicKey'], 'pk_test_value');
    expect(parsed.queryParameters['clientSecret'], 'secret_test_value');
  });

  test('rejects redirections, phishing lookalikes and credentials-in-URL', () {
    for (final url in <String?>[
      null,
      '',
      '   ',
      'http://accept.paymob.com/unifiedcheckout/?publicKey=a&clientSecret=b',
      'https://accept.paymob.com.evil.test/unifiedcheckout/?publicKey=a&clientSecret=b',
      'https://paymob.com.evil.test/unifiedcheckout/?publicKey=a&clientSecret=b',
      'https://accept.paymob.com@evil.test/unifiedcheckout/?publicKey=a&clientSecret=b',
      'https://attacker:password@accept.paymob.com/unifiedcheckout/?publicKey=a&clientSecret=b',
      'javascript:alert(1)',
      'file:///etc/passwd',
      'https://accept.paymob.com:444/unifiedcheckout/?publicKey=a&clientSecret=b',
      'https://accept.paymob.com/other/?publicKey=a&clientSecret=b',
      'https://accept.paymob.com/unifiedcheckout/?publicKey=a&clientSecret=b#redirect',
      'https://accept.paymob.com/unifiedcheckout/?publicKey=a',
      'https://accept.paymob.com/unifiedcheckout/?clientSecret=b',
      'https://accept.paymob.com/unifiedcheckout/?publicKey=&clientSecret=b',
      'https://accept.paymob.com/unifiedcheckout/?publicKey=a&clientSecret=',
    ]) {
      expect(OwnerSubscriptionRepository.trustedPaymobCheckoutUri(url), isNull,
          reason: 'unsafe checkout URL must fail closed');
    }
  });

  test('checkout and plan upgrade never assert payment completion before Paymob', () {
    final repository = File(
      'lib/core/repositories/owner_subscription_repository.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/owner/screens/subscription_plans_screen.dart',
    ).readAsStringSync();
    final handler = File(
      'supabase/functions/create_paymob_intention/index.ts',
    ).readAsStringSync();

    expect(repository, contains('trustedPaymobCheckoutUri('));
    expect(repository, contains('throw StateError(\'checkout_url_missing_or_unsafe\')'));
    expect(handler, contains('https://accept.paymob.com/unifiedcheckout/'));
    expect(screen, contains("createProOrder("));
    expect(screen, contains("createPaymobCheckout("));
    expect(screen, contains('LaunchMode.externalApplication'));
    expect(screen, contains('فور تأكيد السداد'));
    expect(screen, isNot(contains('AnalyticsService.logSubscriptionActivated(')));
  });
}
