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
  // ⚠️ استبدل هذا الرقم بـ Iframe ID الحقيقي من لوحة تحكم Paymob
  // https://accept.paymob.com > Settings > Payment Integrations
  static const String paymobIframeId = 'YOUR_REAL_IFRAME_ID';

  // 🔌 Supabase Connection Pooling (Supavisor) Configuration
  // Direct Connection Port: 5432 | Pooled Connection Port: 6543 (Transaction Mode for Serverless)
  static const int supabasePooledPort = 6543;
}
