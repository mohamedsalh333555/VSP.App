/// إدارة المتغيرات البيئية بأمان تام عند الـ Compile-Time
class AppEnv {
  static String get supabaseUrl {
    const url = String.fromEnvironment('SUPABASE_URL');
    if (url.isNotEmpty) return url;
    throw StateError('SUPABASE_URL must be provided via --dart-define=SUPABASE_URL=...');
  }

  static String get supabaseAnonKey {
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (key.isNotEmpty) return key;
    throw StateError('SUPABASE_ANON_KEY must be provided via --dart-define=SUPABASE_ANON_KEY=...');
  }

  // Paymob Public Key فقط في التطبيق
  static String get paymobPublicKey {
    const key = String.fromEnvironment('PAYMOB_PUBLIC_KEY');
    if (key.isNotEmpty) return key;
    throw StateError('PAYMOB_PUBLIC_KEY must be provided via --dart-define=PAYMOB_PUBLIC_KEY=...');
  }
}
