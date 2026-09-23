/// Compile-time configuration. Production builds must provide explicit values.
class AppEnv {
  static String get supabaseUrl {
    const value = String.fromEnvironment('SUPABASE_URL');
    if (value.isEmpty) throw StateError('SUPABASE_URL is required at build time.');
    return value;
  }

  static String get supabaseAnonKey {
    const value = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (value.isEmpty) throw StateError('SUPABASE_ANON_KEY is required at build time.');
    return value;
  }

  static String get paymobPublicKey {
    const value = String.fromEnvironment('PAYMOB_PUBLIC_KEY');
    if (value.isEmpty) throw StateError('PAYMOB_PUBLIC_KEY is required for Paymob payment flows.');
    return value;
  }

  static String get googleWebClientId {
    const value = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    if (value.isEmpty) throw StateError('GOOGLE_WEB_CLIENT_ID is required for Google web sign-in.');
    return value;
  }

  static String get googleIosClientId {
    const value = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
    if (value.isEmpty) throw StateError('GOOGLE_IOS_CLIENT_ID is required for Google iOS sign-in.');
    return value;
  }
}
