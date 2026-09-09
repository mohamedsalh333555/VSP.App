import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/repositories/team_repository.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../player/widgets/add_player_sheet.dart';
import 'team_management_service.dart';

/// Business-logic mixin for [MyTeamScreen], keeping the screen widget thin.
///
/// Manages team create/update/member-add/member-remove flows and delegates
/// repository & storage calls through their respective services.
mixin MyTeamController<T extends StatefulWidget> on State<T> {
  // ── State that the mixin owns ─────────────────────────────────────────────
  List<UserModel> get teamMembers;
  Team? get localTeam;
  bool get isSaving;
  set isSavingValue(bool v);
  void refreshTeamMembers(UserModel user);

  // ── Add player ────────────────────────────────────────────────────────────
  void showAddPlayerSheet(Team? currentTeam) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddPlayerSheet(
        existingMemberUids: [
          currentTeam?.memberUids.first ?? auth.currentUser?.uid ?? '',
          ...teamMembers.map((m) => m.uid),
        ],
        onPlayerAdded: (UserModel user) => _onPlayerAdded(currentTeam, user),
      ),
    );
  }

  Future<void> _onPlayerAdded(Team? currentTeam, UserModel user) async {
    if (currentTeam != null) {
      // Capture messenger before the async gap
      final messenger = ScaffoldMessenger.of(context);
      try {
        await TeamRepository().addMemberToTeam(
          currentTeam.id,
          user.uid,
          user.profileImageUrl ?? '',
        );
        if (mounted) {
          setState(() {
            if (!teamMembers.any((m) => m.uid == user.uid)) {
              teamMembers.add(user);
            }
          });
        }
      } catch (e) {
        if (!mounted) return;
        final errorMsg = e.toString().replaceAll('Exception:', '').trim();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.warning_2_copy, color: VSPColors.error, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMsg,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: VSPColors.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(VSPRadius.md),
              side: const BorderSide(color: VSPColors.error, width: 1.5),
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          if (!teamMembers.any((m) => m.uid == user.uid)) {
            teamMembers.add(user);
          }
        });
      }
    }
  }

  // ── Remove member ─────────────────────────────────────────────────────────
  Future<void> handleRemoveMember(UserModel member) async {
    final team = localTeam;
    if (team != null) {
      try {
        await TeamRepository()
            .removeMemberFromTeam(team.id, member.uid, member.profileImageUrl ?? '');
        if (!mounted) return;
        setState(() => teamMembers.removeWhere((m) => m.uid == member.uid));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.memberRemovedSuccess),
            backgroundColor: VSPColors.accent,
          ),
        );
      } catch (e) {
        if (mounted) {
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          final displayMsg =
              TeamManagementService.formatTeamErrorMessage(e, isArabic: isAr);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(displayMsg), backgroundColor: VSPColors.error),
          );
        }
      }
    } else {
      setState(() => teamMembers.removeWhere((m) => m.uid == member.uid));
    }
  }

  // ── Create team ───────────────────────────────────────────────────────────
  Future<void> handleCreateTeam(UserModel? user) async {
    final l10n = AppLocalizations.of(context)!;
    final teamName = teamNameText;
    if (teamName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.enterTeamNameError), backgroundColor: VSPColors.error));
      return;
    }
    if (user == null) return;

    isSavingValue = true;
    setState(() {});
    try {
      final logoUrl = await _uploadLogoIfSelected(user.uid);
      final payload = TeamManagementService.buildCreateTeamPayload(
        name: teamName,
        sportType: selectedSport,
        user: user,
        logoUrl: logoUrl,
        members: teamMembers,
      );

      final teamId = await TeamRepository().createTeam(payload);

      if (teamId != null && mounted) {
        await reloadTeam();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.teamCreatedSuccess), backgroundColor: VSPColors.accent));
        }
      } else if (mounted) {
        VSPFeedback.showError(context, 'فشل إنشاء الفريق. يرجى إعادة المحاولة.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorOccurred(e.toString())), backgroundColor: VSPColors.error));
      }
    } finally {
      if (mounted) {
        isSavingValue = false;
        setState(() {});
      }
    }
  }

  // ── Update team ───────────────────────────────────────────────────────────
  Future<void> handleUpdateTeam(Team team) async {
    final l10n = AppLocalizations.of(context)!;
    isSavingValue = true;
    setState(() {});
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).userModel;
      final logoUrl = await _uploadLogoIfSelected(user?.uid ?? 'unknown');

      final payload = TeamManagementService.buildUpdateTeamPayload(
        name: teamNameText,
        sportType: selectedSport,
        existingTeam: team,
        user: user,
        logoUrl: logoUrl,
        members: teamMembers,
      );

      await TeamRepository().updateTeam(team.id, payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.teamUpdatedSuccess), backgroundColor: VSPColors.accent));
        clearSelectedLogo();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorOccurred(e.toString())), backgroundColor: VSPColors.error));
      }
    } finally {
      if (mounted) {
        isSavingValue = false;
        setState(() {});
      }
    }
  }

  // ── Required overrides ────────────────────────────────────────────────────
  String get teamNameText;
  String get selectedSport;
  XFile? get selectedLogo;
  void clearSelectedLogo();
  Future<void> reloadTeam();

  // ── Private helpers ───────────────────────────────────────────────────────
  Future<String?> _uploadLogoIfSelected(String userId) async {
    if (selectedLogo == null) return null;
    return StorageService().uploadFile(
      file: selectedLogo!,
      bucket: 'profile-pictures',
      path: 'teams/$userId/logo/logo_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
  }
}
