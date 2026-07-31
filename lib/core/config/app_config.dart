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
}
