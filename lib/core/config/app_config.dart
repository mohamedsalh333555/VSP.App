class AppConfig {
  static const bool bypassOtp = false;
  static const bool demoMode = false;
  static const bool enableOnlinePayment = false;

  // OTP Configuration
  // 🛡️ Set to false to force real email OTP sending via Supabase/Resend
  static const bool useMockOtp = false;
  static const String mockOtpCode = "123456";
  static const int otpCountdownSeconds = 60;

  // Sandbox & Verification Configuration
  static const bool autoApproveOwnerInDebug = false;

  // 💳 Paymob Payment Gateway Configuration
  static const String paymobIframeId = '1059114';
  static const String paymobCardIntegrationId = String.fromEnvironment('PAYMOB_CARD_INTEGRATION_ID', defaultValue: '5772488');
  static const String paymobWalletIntegrationId = String.fromEnvironment('PAYMOB_WALLET_INTEGRATION_ID', defaultValue: '5772511');
  static const String paymobApiKey = String.fromEnvironment('PAYMOB_API_KEY', defaultValue: 'ZXlKaGJHY2lPaUpJVXpVeE1pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SmpiR0Z6Y3lJNklrMWxjbU5vWVc1MElpd2ljSEp2Wm1sc1pWOXdheUk2TVRFNU5ETTFOeXdpYm1GdFpTSTZJbWx1YVhScFlXd2lmUS5td0FOSGhWbzB5a2N1R2swb3UwYk5zMlRveEpscWNwY2YwZUZxb1liOXlEaUU3MmV4TFEzVDNJTnBqREVleGNWQkE2VFQwYzk3OHZLWWRoOGtsbXFMUQ==');
  static const String paymobPublicKey = String.fromEnvironment('PAYMOB_PUBLIC_KEY', defaultValue: 'egy_pk_test_NO6ul8ku1EsmWTuXrnz6l0CHnY0c90dx');
  static const String paymobSecretKey = String.fromEnvironment('PAYMOB_SECRET_KEY', defaultValue: 'egy_sk_test_bd1135d9086f141c2a800d726aa7c118ff988321ab75aba708252df996658697');
  static const String paymobHmac = String.fromEnvironment('PAYMOB_HMAC', defaultValue: 'F3D831A6ABCF88F4A2FCFB8B92C92623');

  // 🔌 Supabase Connection Pooling (Supavisor) Configuration
  // Direct Connection Port: 5432 | Pooled Connection Port: 6543 (Transaction Mode for Serverless)
  static const int supabasePooledPort = 6543;
}
