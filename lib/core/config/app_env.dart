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

  // Google OAuth Client IDs
  static const String googleWebClientId = '653374694721-cps5rfs3r51hlprlkrt3pm4qp247pf66.apps.googleusercontent.com';
  static const String googleIosClientId = '860837572098-2uv3tlten0tq4tp4ff7g0d79dmi94qnk.apps.googleusercontent.com';
}
