/// Legacy configuration surface. Business and operational truth lives in Supabase.
class AppConfig {
  const AppConfig._();
  static const bool isRetired = true;

  // Paymob Payment Gateway Configuration
  static const String paymobCardIntegrationId = String.fromEnvironment(
    'PAYMOB_CARD_INTEGRATION_ID',
    defaultValue: '5772488',
  );
  static const String paymobWalletIntegrationId = String.fromEnvironment(
    'PAYMOB_WALLET_INTEGRATION_ID',
    defaultValue: '5772511',
  );
}
