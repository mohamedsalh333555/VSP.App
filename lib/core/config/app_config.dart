import 'app_env.dart';

class AppConfig {
  static const bool enableOnlinePayment = true;

  // 💳 Paymob Payment Gateway Configuration (Client Keys Only)
  static const String paymobIframeId = '1059114';
  static const String paymobCardIntegrationId = String.fromEnvironment('PAYMOB_CARD_INTEGRATION_ID', defaultValue: '5772488');
  static const String paymobWalletIntegrationId = String.fromEnvironment('PAYMOB_WALLET_INTEGRATION_ID', defaultValue: '5772511');
  
  static String get paymobPublicKey => AppEnv.paymobPublicKey;

  // 🔌 Supabase URL & Key References
  static String get supabaseUrl => AppEnv.supabaseUrl;
  static String get supabaseAnonKey => AppEnv.supabaseAnonKey;

  static const int supabasePooledPort = 6543;
}
