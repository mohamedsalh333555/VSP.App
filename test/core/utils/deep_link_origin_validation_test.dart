import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/utils/deep_link_helper.dart';

void main() {
  test('trusted Supabase OAuth and reset callbacks are recognized', () {
    for (final raw in [
      'io.supabase.fluttervsp://login-callback/?role=owner&code=sample',
      'io.supabase.fluttervsp://reset-callback/#access_token=fixture',
      'vspapp://login-callback/?code=abc',
      'https://vspapp.online/auth/callback?code=verified-shape',
      'https://vspapp.online/?code=web-oauth',
      'https://vspapp.online/login-callback#error=access_denied',
    ]) {
      expect(DeepLinkHelper.isOAuthCallback(Uri.parse(raw)), true,
          reason: 'registered callback should be detected: $raw');
    }
  });

  test('OAuth-shaped content on foreign hosts and unrelated paths is never trusted', () {
    for (final raw in [
      'https://attacker.example/login-callback?code=forged&role=owner',
      'https://attacker.example/#access_token=forged',
      'https://vspapp.online.evil.example/?code=forged',
      'http://vspapp.online/auth/callback?code=forged',
      'https://vspapp.online/match/id?code=forged',
      'https://user@vspapp.online/?code=forged',
      'vspapp://evil-callback/?code=forged',
      'io.supabase.fluttervsp://login-callback/extra?code=forged',
      'https://vspapp.online/random/path?error=forged',
      'https://vsp.app/?code=forged',
    ]) {
      expect(DeepLinkHelper.isOAuthCallback(Uri.parse(raw)), false,
          reason: 'untrusted callback origin must be rejected: $raw');
    }
  });

  test('supported HTTPS and custom scheme links preserve only safe route ID', () {
    final cases = <String, String>{
      'vspapp://match/BOOK-123?invite=1': '/match/BOOK-123?invite=1',
      'vspapp://collective/abc_123': '/collective/abc_123',
      'https://vspapp.online/team/T_123': '/team/T_123',
      'https://vspapp.online/championship/CH-50': '/championship/CH-50',
      'https://vsp.app/match/M123': '/match/M123',
      'https://vspapp.online/match?id=M99': '/match/M99',
      'https://vspapp.online/match/X?invite=0': '/match/X',
    };
    for (final entry in cases.entries) {
      expect(DeepLinkHelper.parse(Uri.parse(entry.key))?.routePath, entry.value,
          reason: entry.key);
    }
  });

  test('arbitrary origins, ambiguous paths and oversized IDs fail closed', () {
    final oversized = List.filled(129, 'a').join();
    final cases = [
      'http://vspapp.online/match/id',
      'https://evil.example/match/id',
      'https://vspapp.online.evil.example/match/id',
      'https://user@vspapp.online/match/id',
      'https://vspapp.online:444/match/id',
      'https://vspapp.online/match/id/extra',
      'https://vspapp.online/match/id%2Fextra',
      'https://vspapp.online/match/no%20space',
      'https://vspapp.online/match?id=x&id=y',
      'https://vspapp.online/match/id#access_token=private',
      'vspapp://match/a/extra',
      'vspapp://match/no%20space',
      'vspapp://match',
      'vspapp://match/$oversized',
      'vspapp://login-callback/?code=secret',
      'javascript:alert(1)',
      'file:///etc/passwd',
    ];
    for (final raw in cases) {
      expect(DeepLinkHelper.parse(Uri.parse(raw)), isNull, reason: raw);
    }
  });

  test('deep link entrypoint does not trust callback roles or store unknown links', () {
    final main = File('lib/main.dart').readAsStringSync();
    final handler = main.substring(main.indexOf('void _handleDeepLink(Uri uri)'));
    expect(handler, contains('DeepLinkHelper.isOAuthCallback(uri)'));
    expect(handler, isNot(contains('auth.setUserType(role)')));
    expect(handler, isNot(contains("prefs.setString('pending_oauth_role'")));
    expect(handler, isNot(contains("SecureStorageService.writeSecure('pending_oauth_role'")));
    final parse = handler.indexOf('final parsed = DeepLinkHelper.parse(uri);');
    final reject = handler.indexOf('if (parsed == null)', parse);
    final persist = handler.indexOf("prefs.setString('pending_deep_link'", reject);
    expect(parse, greaterThanOrEqualTo(0));
    expect(reject, greaterThan(parse));
    expect(persist, greaterThan(reject));

    final initiator = File(
      'lib/core/providers/auth/auth_oauth_coordinator.dart',
    ).readAsStringSync();
    expect(initiator, contains("prefs.setString('pending_oauth_role'"));
    expect(initiator, contains("SecureStorageService.writeSecure('pending_oauth_role'"));
    // Profile role is stored when the local OAuth request starts, not parsed
    // from an arbitrary later URL query parameter.
  });
}
