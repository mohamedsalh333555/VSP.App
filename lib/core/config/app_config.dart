class AppConfig {
  static const bool bypassOtp = false;
  static const bool demoMode = false;
  static const bool enableOnlinePayment = false;

  // OTP Configuration
  static const bool useMockOtp = true; // Set to false for production
  static const String mockOtpCode = "123456";
  static const int otpCountdownSeconds = 60;
}
