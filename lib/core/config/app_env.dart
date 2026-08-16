/// 🔐 إدارة المتغيرات البيئية بأمان تام عند الـ Compile-Time
class AppEnv {
  static String get supabaseUrl {
    const url = String.fromEnvironment('SUPABASE_URL');
    return url.isNotEmpty ? url : 'https://mktqkddbcddrxjxabdua.supabase.co';
  }

  static String get supabaseAnonKey {
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    return key.isNotEmpty ? key : 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE';
  }

  // 💳 Paymob Public Key فقط في التطبيق
  static String get paymobPublicKey {
    const key = String.fromEnvironment('PAYMOB_PUBLIC_KEY');
    return key.isNotEmpty ? key : 'egy_pk_test_NO6ul8ku1EsmWTuXrnz6l0CHnY0c90dx';
  }
}
