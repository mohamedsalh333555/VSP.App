import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/ui/tokens/vsp_tokens.dart';
import 'team_invitations_sheet.dart';

/// Reusable, testable entry point shown in the player's Teams dashboard.
/// The inbox itself stays account-scoped and performs its own authorization
/// checks before displaying or responding to an invitation.
class TeamInvitationsAction extends StatelessWidget {
  const TeamInvitationsAction({
    super.key,
    required this.userId,
    this.onMembershipChanged,
    this.loadInvitations,
    this.respondToInvitation,
  });

  final String userId;
  final Future<void> Function()? onMembershipChanged;
  final Future<List<Map<String, dynamic>>> Function(String userId)?
      loadInvitations;
  final Future<void> Function(String invitationId, bool accept)?
      respondToInvitation;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return IconButton(
      tooltip: isArabic ? 'دعوات الفرق' : 'Team invitations',
      icon: const Icon(Iconsax.sms_copy, color: VSPColors.accent),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => TeamInvitationsSheet(
          userId: userId,
          onMembershipChanged: onMembershipChanged,
          loadInvitations: loadInvitations,
          respondToInvitation: respondToInvitation,
        ),
      ),
    );
  }
}
