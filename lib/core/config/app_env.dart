import 'package:flutter/foundation.dart';
import '../services/logger_service.dart';

/// إدارة المتغيرات البيئية بأمان تام عند الـ Compile-Time مع Fallbacks موثوقة للتشغيل الفوري
class AppEnv {
  static String get supabaseUrl {
    const url = String.fromEnvironment('SUPABASE_URL');
    if (url.isNotEmpty) return url;
    if (kReleaseMode) {
      VSPLogger.w(' Production build running with standard project SUPABASE_URL.');
    }
    return 'https://mktqkddbcddrxjxabdua.supabase.co';
  }

  static String get supabaseAnonKey {
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (key.isNotEmpty) return key;
    if (kReleaseMode) {
      VSPLogger.w(' Production build running with standard project SUPABASE_ANON_KEY.');
    }
    return 'sb_publishable_ht3eLKZoEiQ49hh413Yfgw_E-S4k3-k';
  }

  // Paymob Public Key فقط في التطبيق
  static String get paymobPublicKey {
    const key = String.fromEnvironment('PAYMOB_PUBLIC_KEY');
    if (key.isNotEmpty) return key;
    if (kReleaseMode) {
      VSPLogger.w(' Production build running with standard project PAYMOB_PUBLIC_KEY.');
    }
    return 'egy_pk_test_NO6ul8ku1EsmWTuXrnz6l0CHnY0c90dx';
  }

  // Paymob Test Secret Key for direct testing fallback
  static String get paymobSecretKey {
    const key = String.fromEnvironment('PAYMOB_SECRET_KEY');
    if (key.isNotEmpty) return key;
    return 'egy_sk_test_bd1135d9086f141c2a800d726aa7c118ff988321ab75aba708252df996658697';
  }

  // Google OAuth Client IDs
  static const String googleWebClientId = '860837572098-uad28p5kb2n567utmk382ogqorpn6vid.apps.googleusercontent.com';
  static const String googleIosClientId = '860837572098-2uv3tlten0tq4tp4ff7g0d79dmi94qnk.apps.googleusercontent.com';
}
