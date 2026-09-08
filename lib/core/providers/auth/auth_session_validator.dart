import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';

/// Pure stateless session validation predicates for AuthProvider.
/// No Supabase I/O — all methods accept already-fetched data as arguments.
///
/// Covers:
/// - Unregistered OAuth guard (login-only path with no phone)
/// - Registration completeness heuristic (phone + isRegistrationComplete flag)
/// - Email verification sync from Supabase Auth source of truth
/// - Auto-login redirect condition (complete user with phone)
/// - OAuth role override condition (pending role differs from DB role)
class AuthSessionValidator {
  const AuthSessionValidator._();

  // ─── Unregistered OAuth Guard ──────────────────────────────────────────────

  /// Returns true if this sign-in attempt should be rejected because the user
  /// tried to log in (not register) with a social account that has no phone number.
  ///
  /// [isLoginOnly] comes from SharedPreferences 'pending_oauth_is_login_only'.
  /// [userData] is the raw map from the users table (may be empty or null).
  static bool isUnregisteredSocialLoginAttempt({
    required bool isLoginOnly,
    required Map<String, dynamic>? userData,
  }) {
    if (!isLoginOnly) return false;
    final phone = userData?['phone']?.toString().trim() ?? '';
    return phone.isEmpty;
  }

  // ─── OAuth Role Override ───────────────────────────────────────────────────

  /// Returns true if the DB role should be overridden with the pending role.
  ///
  /// This handles Google/Apple OAuth flows where the sign-up trigger defaults
  /// to 'player' even when the user selected 'owner' before redirecting.
  static bool shouldOverrideOAuthRole({
    required String? pendingRole,
    required Map<String, dynamic> userData,
  }) {
    if (pendingRole == null) return false;
    final isComplete = userData['is_registration_complete'] as bool? ?? false;
    if (isComplete) return false; // Already registered — don't override
    return userData['role'] != pendingRole;
  }

  // ─── Registration Completeness ────────────────────────────────────────────

  /// Returns true if the user profile qualifies as "existing + complete":
  /// - The registration_complete flag is set AND
  /// - A non-empty phone number is present
  static bool isExistingCompleteUser(Map<String, dynamic> userData) {
    final isComplete =
        userData['is_registration_complete'] == true ||
        userData['isRegistrationComplete'] == true;
    final phone = userData['phone']?.toString().trim() ?? '';
    return isComplete && phone.isNotEmpty;
  }

  // ─── Phone Validity ───────────────────────────────────────────────────────

  /// Returns true if [userModel] has a valid (non-empty) phone number.
  static bool hasValidPhone(UserModel? userModel) {
    return userModel?.phone?.trim().isNotEmpty == true;
  }

  // ─── Email Verification Sync ──────────────────────────────────────────────

  /// Returns true if the Supabase Auth session confirms the email is verified,
  /// but the local UserModel flag is still false (DB is stale).
  static bool needsEmailVerificationSync({
    required User? authUser,
    required UserModel? userModel,
  }) {
    if (authUser?.emailConfirmedAt == null) return false;
    return userModel?.isEmailVerified == false;
  }

  // ─── Auto-Login Redirect ──────────────────────────────────────────────────

  /// Returns true if [userType] (sign-up role context) should be cleared,
  /// letting GoRouter route based on the UserModel's DB role instead.
  ///
  /// Triggered when the user has a complete registration with a phone number.
  static bool shouldClearUserTypeForAutoLogin(UserModel? userModel) {
    if (userModel == null) return false;
    return userModel.isRegistrationComplete &&
        (userModel.phone?.isNotEmpty == true);
  }

  // ─── Registration Auto-Fix ────────────────────────────────────────────────

  /// Returns true if isRegistrationComplete should be patched to true.
  ///
  /// Fix: New social sign-ups without a phone should NOT be auto-completed.
  /// Only apply the patch if the user actually has a valid phone.
  static bool shouldAutoPatchRegistrationComplete(UserModel? userModel) {
    if (userModel == null) return false;
    return !userModel.isRegistrationComplete && hasValidPhone(userModel);
  }
}
