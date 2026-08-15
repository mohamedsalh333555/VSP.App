import 'package:flutter/foundation.dart';

/// 🔐 إدارة المتغيرات البيئية بأمان تام عند الـ Compile-Time
class AppEnv {
  static String get supabaseUrl {
    const url = String.fromEnvironment('SUPABASE_URL');
    if (url.isEmpty && kReleaseMode) {
      throw UnsupportedError('❌ خطأ أمني: SUPABASE_URL غير محدد في بيئة الإنتاج (--dart-define).');
    }
    return url.isNotEmpty ? url : 'https://mktqkddbcddrxjxabdua.supabase.co';
  }

  static String get supabaseAnonKey {
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (key.isEmpty && kReleaseMode) {
      throw UnsupportedError('❌ خطأ أمني: SUPABASE_ANON_KEY غير محدد في بيئة الإنتاج (--dart-define).');
    }
    return key.isNotEmpty ? key : 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE';
  }

  // 💳 Paymob Public Key فقط في التطبيق
  static String get paymobPublicKey {
    const key = String.fromEnvironment('PAYMOB_PUBLIC_KEY');
    return key.isNotEmpty ? key : 'egy_pk_test_NO6ul8ku1EsmWTuXrnz6l0CHnY0c90dx';
  }
}
