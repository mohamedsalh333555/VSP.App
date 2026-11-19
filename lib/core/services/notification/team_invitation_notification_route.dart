/// Metadata is a navigation hint, never an authorization decision.
/// Navigation only opens the active player's own RLS-filtered invitation inbox.
class TeamInvitationNotificationRoute {
  const TeamInvitationNotificationRoute._();

  static bool opensCurrentPlayerInbox(
    Map<String, dynamic>? metadata,
    String? signedInUserId,
  ) {
    if (signedInUserId == null || signedInUserId.trim().isEmpty) return false;
    if (metadata == null ||
        metadata['source'] != 'team_membership' ||
        metadata['event'] != 'invitation_received') {
      return false;
    }

    // Untrusted notification metadata must never redirect a signed-in player
    // into a different recipient's inbox (including missing recipient data).
    final recipient = metadata['invited_user_id'];
    final invitationId = metadata['invitation_id'];
    if (recipient is! String || recipient != signedInUserId ||
        invitationId is! String || invitationId.trim().isEmpty) {
      return false;
    }
    return true;
  }
}
