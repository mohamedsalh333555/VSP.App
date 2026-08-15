import 'package:flutter/foundation.dart';

/// 🔐 إدارة المتغيرات البيئية بأمان تام عند الـ Compile-Time
class AppEnv {
  static String get supabaseUrl {
    const url = String.fromEnvironment('SUPABASE_URL');
    if (url.isEmpty && kReleaseMode) {
      throw UnsupportedError('❌ خطأ أمني: SUPABASE_URL غير محدد في بيئة الإنتاج (--dart-define).');
    }
    return url.isNotEmpty ? url : 'https://mktqkddbcddrxjxabdua.supabase.co'; // Fallback للتطوير فقط
  }

  static String get supabaseAnonKey {
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (key.isEmpty && kReleaseMode) {
      throw UnsupportedError('❌ خطأ أمني: SUPABASE_ANON_KEY غير محدد في بيئة الإنتاج (--dart-define).');
    }
    return key.isNotEmpty ? key : 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE'; // Fallback للتطوير فقط
  }

  static String get paymobApiKey {
    const key = String.fromEnvironment('PAYMOB_API_KEY');
    if (key.isEmpty && kReleaseMode) {
      throw UnsupportedError('❌ خطأ أمني: PAYMOB_API_KEY غير محدد في بيئة الإنتاج.');
    }
    return key.isNotEmpty ? key : 'ZXlKaGJHY2lPaUpJVXpVeE1pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SmpiR0Z6Y3lJNklrMWxjbU5vWVc1MElpd2ljSEp2Wm1sc1pWOXdheUk2TVRFNU5ETTFOeXdpYm1GdFpTSTZJbWx1YVhScFlXd2lmUS5td0FOSGhWbzB5a2N1R2swb3UwYk5zMlRveEpscWNwY2YwZUZxb1liOXlEaUU3MmV4TFEzVDNJTnBqREVleGNWQkE2VFQwYzk3OHZLWWRoOGtsbXFMUQ==';
  }

  static String get paymobSecretKey {
    const key = String.fromEnvironment('PAYMOB_SECRET_KEY');
    return key.isNotEmpty ? key : 'egy_sk_test_bd1135d9086f141c2a800d726aa7c118ff988321ab75aba708252df996658697';
  }

  static String get paymobPublicKey {
    const key = String.fromEnvironment('PAYMOB_PUBLIC_KEY');
    return key.isNotEmpty ? key : 'egy_pk_test_NO6ul8ku1EsmWTuXrnz6l0CHnY0c90dx';
  }

  static String get paymobHmac {
    const key = String.fromEnvironment('PAYMOB_HMAC');
    return key.isNotEmpty ? key : 'F3D831A6ABCF88F4A2FCFB8B92C92623';
  }
}
