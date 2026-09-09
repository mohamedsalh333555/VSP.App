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
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/vsp_back_button.dart';
import '../../widgets/my_team/my_team_controller.dart';
import '../../widgets/my_team/team_achievements_section.dart';
import '../../widgets/my_team/team_action_buttons.dart';
import '../../widgets/my_team/team_dialogs.dart';
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

class _MyTeamScreenState extends State<MyTeamScreen> with MyTeamController<MyTeamScreen> {
  final TextEditingController _teamNameController = TextEditingController();
  String _selectedSport = 'Football';

  @override
  final List<UserModel> teamMembers = [];

  @override
  Team? localTeam;

  bool _isLoadingMembers = true;

  bool _isSaving = false;

  @override
  bool get isSaving => _isSaving;

  @override
  set isSavingValue(bool v) => _isSaving = v;

  XFile? _selectedLogo;

  @override
  XFile? get selectedLogo => _selectedLogo;

  @override
  void clearSelectedLogo() => _selectedLogo = null;

  @override
  String get teamNameText => _teamNameController.text;

  @override
  String get selectedSport => _selectedSport;

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

  @override
  Future<void> reloadTeam() => _initialLoad();

  @override
  void refreshTeamMembers(UserModel user) {
    if (!teamMembers.any((m) => m.uid == user.uid)) {
      teamMembers.add(user);
    }
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
        localTeam = team;

        _teamSubscription = TeamRepository().streamTeam(team.id).listen((data) async {
          if (data.isNotEmpty && mounted) {
            final updatedTeam = await TeamRepository().getTeam(team.id);
            if (updatedTeam != null && mounted) {
              setState(() {
                _teamNameController.text = updatedTeam.name;
                _selectedSport = updatedTeam.sportType;
                localTeam = updatedTeam;
              });
            }
          }
        }, onError: (err) {
          VSPLogger.w('Team realtime stream notice: $err');
        });

        await _loadMemberDetails(team);
      } else {
        setState(() {
          localTeam = null;
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
          teamMembers.clear();
          teamMembers.addAll(members);
          _isLoadingMembers = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.uid;

    if (uid == null) return const Scaffold(body: Center(child: Text("Not authenticated")));

    if (_isLoadingMembers && localTeam == null) {
      return const Scaffold(
        backgroundColor: VSPColors.background,
        body: Center(child: CircularProgressIndicator(color: VSPColors.accent)),
      );
    }

    final team = localTeam;
    final isCaptain = _isCaptain(team);

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: _buildAppBar(context, l10n, team),
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
        child: _buildBody(context, auth, team, isCaptain, isArabic, uid),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, AppLocalizations l10n, Team? team) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: const VSPBackButton(),
      title: Text(l10n.myTeam, style: Theme.of(context).textTheme.displaySmall),
      actions: [
        if (team != null)
          IconButton(
            icon: const Icon(Iconsax.share_copy, color: VSPColors.accent),
            onPressed: () => SharingService.shareTeam(
              context,
              teamId: team.id,
              teamName: team.name,
              governorate: team.governorate,
            ),
          ),
        const SizedBox(width: 8),
      ],
      centerTitle: true,
    );
  }

  Widget _buildBody(
    BuildContext context,
    AuthProvider auth,
    Team? team,
    bool isCaptain,
    bool isArabic,
    String uid,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (team != null) ...[
          TeamStatsHeader(team: team, membersCount: 1 + teamMembers.length, isArabic: isArabic),
          const SizedBox(height: VSPSpacing.lg),
        ],
        TeamProfileForm(
          teamNameController: _teamNameController,
          selectedSport: _selectedSport,
          selectedLogo: _selectedLogo,
          teamLogoUrl: team?.logoUrl,
          isCaptain: isCaptain,
          isArabic: isArabic,
          onSportChanged: (val) => setState(() => _selectedSport = val),
          onPickLogo: () async {
            final XFile? image =
                await ImagePickService.pick(context, aspectRatio: CropAspectRatioPreset.square);
            if (image != null && mounted) setState(() => _selectedLogo = image);
          },
        ),
        const SizedBox(height: VSPSpacing.lg),
        TeamMembersSection(
          team: team,
          captainUser: auth.userModel,
          teamMembers: teamMembers,
          isLoadingMembers: _isLoadingMembers,
          isCaptain: isCaptain,
          isArabic: isArabic,
          onAddMember: () => showAddPlayerSheet(team),
          onRemoveMember: handleRemoveMember,
        ),
        const SizedBox(height: VSPSpacing.lg),
        if (team != null) ...[
          TeamAchievementsSection(team: team, isArabic: isArabic),
          const SizedBox(height: VSPSpacing.lg),
        ],
        TeamActionButtons(
          team: team,
          isCaptain: isCaptain,
          isSaving: _isSaving,
          hasOtherMembers: teamMembers.isNotEmpty,
          onCreateTeam: () => handleCreateTeam(auth.userModel),
          onUpdateTeam: () => handleUpdateTeam(team!),
          onDeleteTeam: () => TeamDialogs.showDeleteConfirmation(context, team: team!),
          onLeaveTeam: () => TeamDialogs.showLeaveConfirmation(
            context,
            team: team!,
            userId: uid,
            isCaptain: isCaptain,
            onSavingStarted: () => setState(() => _isSaving = true),
            onSavingFinished: () {
              if (mounted) setState(() => _isSaving = false);
            },
          ),
        ),
        const SizedBox(height: VSPSpacing.md),
      ],
    );
  }
}
