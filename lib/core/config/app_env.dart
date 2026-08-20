import 'package:flutter/foundation.dart';

/// 🔐 إدارة المتغيرات البيئية بأمان تام عند الـ Compile-Time
class AppEnv {
  static String get supabaseUrl {
    const url = String.fromEnvironment('SUPABASE_URL');
    if (url.isNotEmpty) return url;
    if (kReleaseMode) {
      throw StateError('Missing required build parameter --dart-define=SUPABASE_URL in production build!');
    }
    return 'https://mktqkddbcddrxjxabdua.supabase.co';
  }

  static String get supabaseAnonKey {
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (key.isNotEmpty) return key;
    if (kReleaseMode) {
      throw StateError('Missing required build parameter --dart-define=SUPABASE_ANON_KEY in production build!');
    }
    return 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE';
  }

  // 💳 Paymob Public Key فقط في التطبيق
  static String get paymobPublicKey {
    const key = String.fromEnvironment('PAYMOB_PUBLIC_KEY');
    if (key.isNotEmpty) return key;
    if (kReleaseMode) {
      throw StateError('Missing required build parameter --dart-define=PAYMOB_PUBLIC_KEY in production build!');
    }
    return 'egy_pk_test_NO6ul8ku1EsmWTuXrnz6l0CHnY0c90dx';
  }
}
