import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../l10n/app_localizations.dart';

enum SignupValidationError {
  pleaseAgreeToTerms,
  fillAllFields,
  pleaseEnterDob,
  invalidPhone,
  passwordMismatch,
  passwordTooShort,
  underRequiredAge,
}

class SignupValidationResult {
  final bool isValid;
  final SignupValidationError? error;
  final String? normalizedPhone;
  final String? fullName;

  const SignupValidationResult._({
    required this.isValid,
    this.error,
    this.normalizedPhone,
    this.fullName,
  });

  factory SignupValidationResult.valid({
    required String normalizedPhone,
    required String fullName,
  }) {
    return SignupValidationResult._(
      isValid: true,
      normalizedPhone: normalizedPhone,
      fullName: fullName,
    );
  }

  factory SignupValidationResult.invalid(SignupValidationError error) {
    return SignupValidationResult._(
      isValid: false,
      error: error,
    );
  }
}

class PasswordStrength {
  final double score;
  final String label;
  final Color color;

  const PasswordStrength({
    required this.score,
    required this.label,
    required this.color,
  });
}

/// Pure domain helper for validating signup inputs, checking password strength,
/// building user payloads, and formatting registration errors.
class SignupValidationService {
  static const int minimumPasswordLength = 8;

  const SignupValidationService._();

  /// Validates all fields for the signup form.
  static SignupValidationResult validateForm({
    required bool agreedToTerms,
    required String firstName,
    required String lastName,
    required String rawPhone,
    required String email,
    required String password,
    required String confirmPassword,
    required DateTime? dateOfBirth,
    required int minimumAge,
  }) {
    if (!agreedToTerms) {
      return SignupValidationResult.invalid(SignupValidationError.pleaseAgreeToTerms);
    }

    final trimmedFirst = firstName.trim();
    final trimmedLast = lastName.trim();
    final trimmedPhone = rawPhone.trim();
    final trimmedEmail = email.trim();

    if (trimmedFirst.isEmpty ||
        trimmedLast.isEmpty ||
        trimmedPhone.isEmpty ||
        trimmedEmail.isEmpty ||
        password.isEmpty) {
      return SignupValidationResult.invalid(SignupValidationError.fillAllFields);
    }

    if (dateOfBirth == null) {
      return SignupValidationResult.invalid(SignupValidationError.pleaseEnterDob);
    }

    final today = DateTime.now();
    final cutoff = DateTime(today.year - minimumAge, today.month, today.day);
    if (dateOfBirth.isAfter(cutoff)) {
      return SignupValidationResult.invalid(SignupValidationError.underRequiredAge);
    }

    final normalizedPhone = PhoneUtils.normalize(trimmedPhone);
    if (normalizedPhone == null || normalizedPhone.length != 11 || !normalizedPhone.startsWith("01")) {
      return SignupValidationResult.invalid(SignupValidationError.invalidPhone);
    }

    if (password != confirmPassword) {
      return SignupValidationResult.invalid(SignupValidationError.passwordMismatch);
    }

    if (password.length < minimumPasswordLength) {
      return SignupValidationResult.invalid(SignupValidationError.passwordTooShort);
    }

    return SignupValidationResult.valid(
      normalizedPhone: normalizedPhone,
      fullName: '$trimmedFirst $trimmedLast',
    );
  }

  /// Maps validation error enum to localized text.
  static String getLocalizedErrorMessage(SignupValidationError error, AppLocalizations l10n) {
    switch (error) {
      case SignupValidationError.pleaseAgreeToTerms:
        return l10n.pleaseAgreeToTerms;
      case SignupValidationError.fillAllFields:
        return l10n.fillAllFields;
      case SignupValidationError.pleaseEnterDob:
        return l10n.pleaseEnterDob;
      case SignupValidationError.invalidPhone:
        return l10n.invalidPhone;
      case SignupValidationError.passwordMismatch:
        return l10n.passwordMismatch;
      case SignupValidationError.passwordTooShort:
        return l10n.passwordTooShort;
      case SignupValidationError.underRequiredAge:
        return l10n.underRequiredAge;
    }
  }

  /// Computes password strength, percentage and visual color indicator.
  static PasswordStrength calculatePasswordStrength(String password) {
    double strength = 0.0;
    if (password.length >= minimumPasswordLength) strength += 0.2;
    if (password.length >= 8) strength += 0.2;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[!@#\$&*~]').hasMatch(password)) strength += 0.2;

    Color color = Colors.red;
    String label = 'Weak';
    if (strength > 0.4) {
      color = VSPColors.textSecondary;
      label = 'Medium';
    }
    if (strength >= 0.8) {
      color = VSPColors.accent;
      label = 'Strong';
    }

    return PasswordStrength(
      score: strength,
      label: label,
      color: color,
    );
  }

  /// Builds standardized user profile payload for Supabase auth metadata.
  static Map<String, dynamic> buildUserDataPayload({
    required String fullName,
    required String normalizedPhone,
    required bool isOwner,
    String? selectedPosition,
    DateTime? dateOfBirth,
  }) {
    return {
      'name': fullName,
      'phone': normalizedPhone,
      'position': isOwner ? null : (selectedPosition ?? 'GK'),
      'date_of_birth': dateOfBirth?.toUtc().toIso8601String(),
    };
  }

  /// Formats and localizes backend signup error messages.
  static String formatSignupError(String? rawError, {required bool isArabic}) {
    final defaultMsg = isArabic ? 'فشل إنشاء الحساب' : 'Account creation failed';
    final errorMsg = rawError ?? defaultMsg;

    if (errorMsg.contains('confirmation email') || errorMsg.contains('unexpected_failure')) {
      return isArabic
          ? 'تعذر إرسال إيميل التأكيد. يرجى مراجعة إعدادات البريد.'
          : 'Could not send confirmation email. Please check email settings.';
    }

    return errorMsg;
  }
}
