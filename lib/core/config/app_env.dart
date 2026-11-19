/// Compile-time configuration with safe SSOT fallbacks for local and production builds.
class AppEnv {
  static const String _defaultSupabaseUrl = 'https://mktqkddbcddrxjxabdua.supabase.co';
  static const String _defaultSupabaseAnonKey = 'sb_publishable_ht3eLKZoEiQ49hh413Yfgw_E-S4k3-k';
  static const String _defaultPaymobPublicKey = 'egy_pk_test_NO6ul8ku1EsmWTuXrnz6l0CHnY0c90dx';

  static String get supabaseUrl {
    const value = String.fromEnvironment('SUPABASE_URL', defaultValue: _defaultSupabaseUrl);
    return value.isNotEmpty ? value : _defaultSupabaseUrl;
  }

  static String get supabaseAnonKey {
    const value = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: _defaultSupabaseAnonKey);
    return value.isNotEmpty ? value : _defaultSupabaseAnonKey;
  }

  static String get paymobPublicKey {
    const value = String.fromEnvironment('PAYMOB_PUBLIC_KEY', defaultValue: _defaultPaymobPublicKey);
    return value.isNotEmpty ? value : _defaultPaymobPublicKey;
  }

  /// Rollout safety only. Actual authorization is enforced by PostgreSQL.
  static bool teamSkillsCupAllowedFor({
    required bool enabled,
    required String projectRef,
    required String supabaseUrl,
    required String publishableKey,
  }) {
    if (!enabled || !RegExp(r'^[a-z0-9]{20}$').hasMatch(projectRef) ||
        publishableKey.length < 21 ||
        publishableKey.contains('service_role') ||
        publishableKey.startsWith('sb_secret_')) {
      return false;
    }
    final uri = Uri.tryParse(supabaseUrl);
    return uri != null && uri.scheme == 'https' &&
        uri.host == '$projectRef.supabase.co' &&
        uri.userInfo.isEmpty && uri.path.isEmpty &&
        uri.query.isEmpty && uri.fragment.isEmpty;
  }

  static bool get teamSkillsCupEnabled {
    const enabled = bool.fromEnvironment(
      'VSP_ENABLE_TEAM_SKILLS_CUP', defaultValue: false);
    const expectedProject = String.fromEnvironment(
      'VSP_TEAM_SKILLS_ALLOWED_PROJECT_REF');
    const explicitUrl = String.fromEnvironment('SUPABASE_URL');
    const explicitKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    return teamSkillsCupAllowedFor(
      enabled: enabled,
      projectRef: expectedProject,
      supabaseUrl: explicitUrl,
      publishableKey: explicitKey,
    );
  }

  static String? get googleWebClientId {
    const value = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    return value.isNotEmpty ? value : null;
  }

  static String? get googleIosClientId {
    const value = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
    return value.isNotEmpty ? value : null;
  }
}
