/// Prevents a previously received link from navigating under a different
/// account after an asynchronous preferences read, sign-out or account switch.
/// Never replaces server-side RLS for the target resource.
abstract final class PendingDeepLinkAccountGuard {
  // RootScreen and app startup both restore pending links. They run on the
  // same Flutter UI isolate; a synchronous lease prevents duplicate pushes
  // while SharedPreferences' asynchronous remove is in flight.
  static bool _isConsuming = false;

  static bool tryAcquire() {
    if (_isConsuming) return false;
    _isConsuming = true;
    return true;
  }

  static void release() {
    _isConsuming = false;
  }

  static bool canReplay({
    required String? requestedForUserId,
    required String? currentUserId,
    required String? profileUserId,
    required bool isAuthenticated,
    required bool isRegistrationComplete,
    String? storedForUserId,
  }) {
    if (!isAuthenticated || !isRegistrationComplete) return false;
    // A link cached while account A was signed in must not be replayed
    // into B, even if it survived a fast platform-level account change.
    if (storedForUserId != null &&
        storedForUserId.isNotEmpty &&
        storedForUserId != requestedForUserId) {
      return false;
    }
    if (requestedForUserId == null || requestedForUserId.trim().isEmpty) {
      return false;
    }
    return requestedForUserId == currentUserId &&
        requestedForUserId == profileUserId;
  }
}
