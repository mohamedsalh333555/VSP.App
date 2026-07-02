import 'package:flutter/foundation.dart';

class AppConfig {
  static const bool bypassOtp = true;
  static const bool demoMode = false;
  static const bool enableOnlinePayment = false;

  // OTP Configuration
  // 🛡️ SECURITY HARDENING: Bind useMockOtp to kDebugMode so that mock OTP is completely
  // unavailable in release builds, preventing any accidental production bypass.
  static const bool useMockOtp = kDebugMode;
  static const String mockOtpCode = "123456";
  static const int otpCountdownSeconds = 60;

  // Sandbox & Verification Configuration
  static const bool autoApproveOwnerInDebug = true;
}
