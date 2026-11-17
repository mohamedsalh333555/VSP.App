/// Client-side route classification to prevent a direct link from opening
/// another role's screens. Authorization for data and mutations MUST still
/// be enforced by Supabase RLS/RPC/Edge handlers.
abstract final class AppRouteRoleGuard {
  static const Set<String> ownerOnly = {
    '/owner',
    '/facility-onboarding',
    '/documentation',
    '/copilot',
    '/subscription-plans',
    '/owner-ledger',
  };

  static const Set<String> playerOnly = {
    '/player',
    '/edit-profile',
    '/notifications',
  };

  static bool isPlayerOnly(String path) =>
      playerOnly.contains(path) ||
      path.startsWith('/match/') ||
      path.startsWith('/team/') ||
      path.startsWith('/collective/');

  static bool isOwnerOnly(String path) => ownerOnly.contains(path);

  /// [isAdmin] is checked using the verified, hydrated auth profile. Do not
  /// use a client-supplied role from an incoming deep-link payload.
  static String? redirectForRole({
    required String path,
    required bool isOwner,
    required bool isAdmin,
  }) {
    if (isAdmin) return null;
    if (isOwner && isPlayerOnly(path)) return '/owner';
    if (!isOwner && isOwnerOnly(path)) return '/';
    return null;
  }
}
