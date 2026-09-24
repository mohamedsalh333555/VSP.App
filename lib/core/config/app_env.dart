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

  static String? get googleWebClientId {
    const value = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    return value.isNotEmpty ? value : null;
  }

  static String? get googleIosClientId {
    const value = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
    return value.isNotEmpty ? value : null;
  }
}
