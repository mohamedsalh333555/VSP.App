/// Prevents a previously received link from navigating under a different
/// account after an asynchronous preferences read, sign-out or account switch.
/// Never replaces server-side RLS for the target resource.
abstract final class PendingDeepLinkAccountGuard {
  static bool canReplay({
    required String? requestedForUserId,
    required String? currentUserId,
    required String? profileUserId,
    required bool isAuthenticated,
    required bool isRegistrationComplete,
  }) {
    if (!isAuthenticated || !isRegistrationComplete) return false;
    if (requestedForUserId == null || requestedForUserId.trim().isEmpty) {
      return false;
    }
    return requestedForUserId == currentUserId &&
        requestedForUserId == profileUserId;
  }
}
