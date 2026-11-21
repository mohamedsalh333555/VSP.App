import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/config/app_env.dart';

void main() {
  const ref = 'vtwgqyxglevcsxwdmhop';
  const url = 'https://vtwgqyxglevcsxwdmhop.supabase.co';
  const key = 'sb_publishable_fake_test_key_only_not_for_prod';

  test('team skills requires explicit matching project and publishable key', () {
    expect(AppEnv.teamSkillsCupAllowedFor(
      enabled: true, projectRef: ref, supabaseUrl: url,
      publishableKey: key,
    ), isTrue);
    expect(AppEnv.teamSkillsCupAllowedFor(
      enabled: false, projectRef: ref, supabaseUrl: url,
      publishableKey: key,
    ), isFalse);
    expect(AppEnv.teamSkillsCupAllowedFor(
      enabled: true, projectRef: ref, supabaseUrl: url,
      publishableKey: '',
    ), isFalse);
  });

  test('staging feature flag cannot accidentally fall back to production URL', () {
    const prod = 'https://mktqkddbcddrxjxabdua.supabase.co';
    for (final candidate in [
      prod,
      'http://vtwgqyxglevcsxwdmhop.supabase.co',
      '$url/rest/v1',
      '$url/?token=secret',
      '$url/#fragment',
      'not a url',
    ]) {
      expect(AppEnv.teamSkillsCupAllowedFor(
        enabled: true, projectRef: ref, supabaseUrl: candidate,
        publishableKey: key,
      ), isFalse, reason: candidate);
    }
  });

  test('browser-facing forbidden service-role/secret credentials fail closed', () {
    for (final key in [
      'sb_secret_do_not_embed_in_flutter',
      'something_service_role_is_never_safe',
    ]) {
      expect(AppEnv.teamSkillsCupAllowedFor(
        enabled: true, projectRef: ref,
        supabaseUrl: url, publishableKey: key,
      ), isFalse);
    }
  });

  test('absent compile flags keep the feature disabled by default', () {
    // CI and ordinary release builds do not define the full opt-in triple.
    expect(AppEnv.teamSkillsCupEnabled, isFalse);
  });
}
