import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/repositories/team_repository.dart';
import '../../../../core/repositories/user_repository.dart';
import '../../../../core/services/image_pick_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/sharing_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/vsp_back_button.dart';
import '../../widgets/add_player_sheet.dart';
import '../../widgets/my_team/team_achievements_section.dart';
import '../../widgets/my_team/team_action_buttons.dart';
import '../../widgets/my_team/team_members_section.dart';
import '../../widgets/my_team/team_profile_form.dart';
import '../../widgets/my_team/team_stats_header.dart';

/// Comprehensive team management screen allowing players and captains to configure their team profile,
/// monitor performance statistics, manage the active roster, view achievements, and handle team lifecycle actions.
class MyTeamScreen extends StatefulWidget {
  const MyTeamScreen({super.key});

  @override
  State<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen> {
  final TextEditingController _teamNameController = TextEditingController();
  String _selectedSport = 'Football';

  final List<UserModel> _teamMembers = [];
  Team? _localTeam; // Track locally for name/sport edits
  bool _isLoadingMembers = true;
  bool _isSaving = false;
  XFile? _selectedLogo;

  StreamSubscription? _teamSubscription;
  StreamSubscription? _membershipSubscription;

  bool _isCaptain(Team? currentTeam) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (currentTeam == null) return true;
    return auth.currentUser?.uid == currentTeam.memberUids.first;
  }

  @override
  void initState() {
    super.initState();
    _initialLoad();

    // Listen to membership changes in Supabase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uid = auth.currentUser?.uid;
      if (uid != null) {
        _membershipSubscription = TeamRepository().streamUserMembership(uid).listen((data) {
          _initialLoad();
        }, onError: (err) {
          VSPLogger.w('Membership realtime stream notice: $err');
        });
      }
    });
  }

  @override
  void dispose() {
    _teamSubscription?.cancel();
    _teamSubscription = null;
    _membershipSubscription?.cancel();
    _membershipSubscription = null;
    _teamNameController.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    _teamSubscription?.cancel();
    _teamSubscription = null;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final team = await TeamRepository().getUserTeam(uid);
    if (mounted) {
      if (team != null) {
        _teamNameController.text = team.name;
        _selectedSport = team.sportType;
        _localTeam = team;

        // Listen to team updates via repository
        _teamSubscription = TeamRepository().streamTeam(team.id).listen((data) async {
          if (data.isNotEmpty && mounted) {
            final updatedTeam = await TeamRepository().getTeam(team.id);
            if (updatedTeam != null && mounted) {
              setState(() {
                _teamNameController.text = updatedTeam.name;
                _selectedSport = updatedTeam.sportType;
                _localTeam = updatedTeam;
              });
            }
          }
        }, onError: (err) {
          VSPLogger.w('Team realtime stream notice: $err');
        });

        await _loadMemberDetails(team);
      } else {
        setState(() {
          _localTeam = null;
          _isLoadingMembers = false;
        });
      }
    }
  }

  Future<void> _loadMemberDetails(Team team) async {
    if (team.memberUids.length > 1) {
      final memberIds = team.memberUids.sublist(1);
      final members = await UserRepository().getUsersByIds(memberIds);
      if (mounted) {
        setState(() {
          _teamMembers.clear();
          _teamMembers.addAll(members);
          _isLoadingMembers = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  void _showAddPlayerSheet(Team? currentTeam) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPlayerSheet(
        existingMemberUids: [
          currentTeam?.memberUids.first ?? Provider.of<AuthProvider>(context, listen: false).currentUser?.uid ?? '',
          ..._teamMembers.map((m) => m.uid)
        ],
        onPlayerAdded: (UserModel user) async {
          if (currentTeam != null) {
            try {
              await TeamRepository().addMemberToTeam(
                currentTeam.id,
                user.uid,
                user.profileImageUrl ?? '',
              );
              if (mounted) {
                setState(() {
                  if (!_teamMembers.any((m) => m.uid == user.uid)) {
                    _teamMembers.add(user);
                  }
                });
              }
            } catch (e) {
              if (!context.mounted) return;
              final errorMsg = e.toString().replaceAll('Exception:', '').trim();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Iconsax.warning_2_copy, color: VSPColors.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          errorMsg,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
            setState(() {
              if (!_teamMembers.any((m) => m.uid == user.uid)) {
                _teamMembers.add(user);
              }
            });
          }
        },
      ),
    );
  }

  Future<void> _handleRemoveMember(UserModel member) async {
    final team = _localTeam;
    if (team != null) {
      try {
        await TeamRepository().removeMemberFromTeam(team.id, member.uid, member.profileImageUrl ?? '');
        if (!mounted) return;
        setState(() => _teamMembers.removeWhere((m) => m.uid == member.uid));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.memberRemovedSuccess),
            backgroundColor: VSPColors.accent,
          ),
        );
      } catch (e) {
        if (mounted) {
          final errorMsg = e.toString().replaceAll('Exception:', '').trim();
          final displayMsg = errorMsg == 'active_match_or_tournament_error'
              ? AppLocalizations.of(context)!.teamMemberDeleteLockError
              : errorMsg;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(displayMsg), backgroundColor: VSPColors.error),
          );
        }
      }
    } else {
      setState(() => _teamMembers.removeWhere((m) => m.uid == member.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.uid;

    if (uid == null) return const Scaffold(body: Center(child: Text("Not authenticated")));

    if (_isLoadingMembers && _localTeam == null) {
      return const Scaffold(
        backgroundColor: VSPColors.background,
        body: Center(child: CircularProgressIndicator(color: VSPColors.accent)),
      );
    }

    final team = _localTeam;
    final isCaptain = _isCaptain(team);

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const VSPBackButton(),
        title: Text(l10n.myTeam, style: Theme.of(context).textTheme.displaySmall),
        actions: [
          if (team != null)
            IconButton(
              icon: const Icon(Iconsax.share_copy, color: VSPColors.accent),
              onPressed: () {
                SharingService.shareTeam(
                  context,
                  teamId: team.id,
                  teamName: team.name,
                  governorate: team.governorate,
                );
              },
            ),
          const SizedBox(width: 8),
        ],
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          VSPSpacing.md,
          VSPSpacing.md,
          VSPSpacing.md,
          (MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 16) +
              100 +
              MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Stats Grid (Show ONLY if team is created)
            if (team != null) ...[
              TeamStatsHeader(
                team: team,
                membersCount: 1 + _teamMembers.length,
                isArabic: isArabic,
              ),
              const SizedBox(height: VSPSpacing.lg),
            ],

            // 2. Team Profile Section (Name, Sport, Logo)
            TeamProfileForm(
              teamNameController: _teamNameController,
              selectedSport: _selectedSport,
              selectedLogo: _selectedLogo,
              teamLogoUrl: team?.logoUrl,
              isCaptain: isCaptain,
              isArabic: isArabic,
              onSportChanged: (val) => setState(() => _selectedSport = val),
              onPickLogo: () async {
                final XFile? image = await ImagePickService.pick(
                  context,
                  aspectRatio: CropAspectRatioPreset.square,
                );
                if (image != null && mounted) setState(() => _selectedLogo = image);
              },
            ),

            const SizedBox(height: VSPSpacing.lg),

            // 3. Members Section
            TeamMembersSection(
              team: team,
              captainUser: auth.userModel,
              teamMembers: _teamMembers,
              isLoadingMembers: _isLoadingMembers,
              isCaptain: isCaptain,
              isArabic: isArabic,
              onAddMember: () => _showAddPlayerSheet(team),
              onRemoveMember: _handleRemoveMember,
            ),

            const SizedBox(height: VSPSpacing.lg),

            // 4. Achievements Section
            if (team != null) ...[
              TeamAchievementsSection(team: team, isArabic: isArabic),
              const SizedBox(height: VSPSpacing.lg),
            ],

            // 5. Action Buttons (Create, Save, Delete, Leave)
            TeamActionButtons(
              team: team,
              isCaptain: isCaptain,
              isSaving: _isSaving,
              hasOtherMembers: _teamMembers.isNotEmpty,
              onCreateTeam: () => _handleCreateTeam(auth.userModel),
              onUpdateTeam: () => _handleUpdateTeam(team!),
              onDeleteTeam: () => _showDeleteConfirmation(team!),
              onLeaveTeam: () => _showLeaveConfirmation(team!, uid),
            ),

            const SizedBox(height: VSPSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreateTeam(UserModel? user) async {
    final l10n = AppLocalizations.of(context)!;
    if (_teamNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.enterTeamNameError), backgroundColor: VSPColors.error));
      return;
    }
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      String? logoUrl;
      if (_selectedLogo != null) {
        logoUrl = await StorageService().uploadFile(
          file: _selectedLogo!,
          bucket: 'profile-pictures',
          path: 'teams/${user.uid}/logo/logo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      List<String> finalUids = [user.uid];
      List<String> finalImages = [user.profileImageUrl ?? ''];
      for (var member in _teamMembers) {
        finalUids.add(member.uid);
        finalImages.add(member.profileImageUrl ?? '');
      }

      final teamId = await TeamRepository().createTeam({
        'name': _teamNameController.text.trim(),
        'sportType': _selectedSport,
        'captainName': user.name ?? 'Captain',
        'captainImageUrl': user.profileImageUrl ?? '',
        'logoUrl': logoUrl ?? '',
        'captainPhone': PhoneUtils.normalize(user.phone ?? ''),
        'memberUids': finalUids,
        'playerImages': finalImages,
        'playersCount': finalUids.length,
        'governorate': user.governorate ?? 'Cairo',
        'stadium': 'TBD',
        'date': 'Upcoming',
        'points': 0,
        'wins': 0,
        'championshipsWon': 0,
        'unlockedBadges': [],
        'currentWinningStreak': 0,
      });

      if (teamId != null && mounted) {
        await _initialLoad();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.teamCreatedSuccess), backgroundColor: VSPColors.accent));
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleUpdateTeam(Team team) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).userModel;
      String? logoUrl;
      if (_selectedLogo != null) {
        logoUrl = await StorageService().uploadFile(
          file: _selectedLogo!,
          bucket: 'profile-pictures',
          path: 'teams/${user?.uid ?? 'unknown'}/logo/logo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      List<String> finalUids = [team.memberUids.first];
      List<String> finalImages = [user?.profileImageUrl ?? team.playerImages.first];
      for (var member in _teamMembers) {
        finalUids.add(member.uid);
        finalImages.add(member.profileImageUrl ?? '');
      }

      await TeamRepository().updateTeam(team.id, {
        'name': _teamNameController.text.trim(),
        'sportType': _selectedSport,
        'logoUrl': logoUrl ?? team.logoUrl,
        'captainImageUrl': user?.profileImageUrl ?? team.captainImageUrl,
        'memberUids': finalUids,
        'playerImages': finalImages,
        'playersCount': finalUids.length,
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.teamUpdatedSuccess), backgroundColor: VSPColors.accent));
        setState(() => _selectedLogo = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorOccurred(e.toString())), backgroundColor: VSPColors.error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showLeaveConfirmation(Team team, String userId) {
    final bool isLeavingCaptain = _isCaptain(team);
    final String contentText = isLeavingCaptain
        ? 'أنت كابتن الفريق. عند مغادرتك، سيتم نقل شارة الكابتنة وقيادة الفريق تلقائياً إلى العضو التالي. هل أنت متأكد؟'
        : 'هل أنت متأكد من رغبتك في مغادرة هذا الفريق؟';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(
          isLeavingCaptain ? 'مغادرة وتسليم الكابتنة' : 'مغادرة الفريق',
          style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          contentText,
          style: const TextStyle(color: VSPColors.textSecondary, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          Row(children: [
            Expanded(
              child: PrimaryButton(
                text: 'إلغاء',
                height: 48,
                color: VSPColors.surfaceAlt,
                textColor: VSPColors.textPrimary,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: VSPSpacing.md),
            Expanded(
              child: PrimaryButton(
                text: 'تأكيد المغادرة',
                height: 48,
                color: VSPColors.error,
                textColor: Colors.white,
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _isSaving = true);
                  try {
                    await TeamRepository().removeMemberFromTeam(team.id, userId, '');
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isLeavingCaptain
                          ? 'تمت مغادرة الفريق ونقل شارة الكابتنة بنجاح.'
                          : 'تمت مغادرة الفريق بنجاح.'),
                      backgroundColor: VSPColors.success,
                    ));
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  } catch (e) {
                    if (!context.mounted) return;
                    final errorMsg = e.toString().replaceAll('Exception:', '').trim();
                    final displayMsg = errorMsg == 'active_match_or_tournament_error'
                        ? AppLocalizations.of(context)!.teamMemberDeleteLockError
                        : errorMsg;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(displayMsg), backgroundColor: VSPColors.error));
                  } finally {
                    if (mounted) setState(() => _isSaving = false);
                  }
                },
              ),
            ),
          ]),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Team team) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(l10n.deleteTeam, style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(l10n.deleteTeamConfirm, style: const TextStyle(color: VSPColors.textSecondary)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          Row(children: [
            Expanded(
              child: PrimaryButton(
                text: l10n.cancel,
                height: 48,
                color: VSPColors.surfaceAlt,
                textColor: VSPColors.textPrimary,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: VSPSpacing.md),
            Expanded(
              child: PrimaryButton(
                text: l10n.delete,
                height: 48,
                color: VSPColors.error,
                textColor: VSPColors.background,
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    final success = await TeamRepository().deleteTeam(team.id);
                    if (!context.mounted) return;
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.teamDeletedSuccess), backgroundColor: VSPColors.error));
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    final isAr = Localizations.localeOf(context).languageCode == 'ar';
                    final errStr = e.toString();
                    String msg = isAr ? 'حدث خطأ أثناء حذف الفريق' : 'Error deleting team';
                    if (errStr.contains('active_match_or_tournament_error') || errStr.contains('team_in_tournament')) {
                      msg = isAr
                          ? 'لا يمكن حذف الفريق لوجود مباريات قادمة أو بطولة نشطة! '
                          : 'Cannot delete team with upcoming matches or active tournament! ';
                    }
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: VSPColors.error));
                  }
                },
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
