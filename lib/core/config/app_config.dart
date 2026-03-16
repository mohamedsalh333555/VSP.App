class AppConfig {
  static const bool bypassOtp = false;
  static const bool demoMode = false;
  static const bool enableOnlinePayment = false;

  // OTP Configuration
  // ⚠️ WARNING: Set useMockOtp = true ONLY during local development/testing.
  // It MUST be false before any production or TestFlight build.
  // When true, any 6-digit code is accepted as valid OTP — a critical security hole.
  static const bool useMockOtp = false;
  static const String mockOtpCode = "123456";
  static const int otpCountdownSeconds = 60;
}
