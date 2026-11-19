/// Deny delayed recovery sign-out unless the original session still owns it.
class PasswordRecoverySessionGuard {
  const PasswordRecoverySessionGuard._();
  static bool isCurrent({
    required String recoveryUserId,
    required String? Function() currentUserId,
  }) {
    if (recoveryUserId.trim().isEmpty) return false;
    try {
      return currentUserId() == recoveryUserId;
    } catch (_) {
      return false; // A disposed provider must not authorize sign-out.
    }
  }
}
