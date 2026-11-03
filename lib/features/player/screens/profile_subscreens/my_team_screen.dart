import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/ui/vsp_ui.dart';
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
  String? _activeUserId;
  int _loadGeneration = 0;
  bool _hasTeamLoadError = false;

  bool _isCaptain(Team? currentTeam) {
    if (currentTeam == null) return true;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final captainId = currentTeam.captainId.trim();
    return captainId.isNotEmpty && auth.currentUser?.id == captainId;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = Provider.of<AuthProvider>(context).currentUser?.id;
    if (uid == _activeUserId) return;

    _activeUserId = uid;
    _loadGeneration++;
    _teamSubscription?.cancel();
    _membershipSubscription?.cancel();
    _teamSubscription = null;
    _membershipSubscription = null;
    localTeam = null;
    teamMembers.clear();
    _teamNameController.clear();
    _selectedSport = 'Football';
    _selectedLogo = null;
    _hasTeamLoadError = false;
    _isLoadingMembers = uid != null;

    if (uid != null) {
      _initialLoad(uid);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _activeUserId != uid) return;
        var skipInitialSnapshot = true;
        _membershipSubscription = TeamRepository()
            .streamUserMembership(uid)
            .listen((_) {
          if (skipInitialSnapshot) {
            skipInitialSnapshot = false;
            return;
          }
          if (_activeUserId == uid) _initialLoad(uid);
        }, onError: (err) {
          VSPLogger.w('Membership realtime stream notice: $err');
          if (mounted && _activeUserId == uid) {
            setState(() {
              _hasTeamLoadError = true;
              _isLoadingMembers = false;
            });
          }
        });
      });
    } else {
      _isLoadingMembers = false;
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _teamSubscription?.cancel();
    _teamSubscription = null;
    _membershipSubscription?.cancel();
    _membershipSubscription = null;
    _teamNameController.dispose();
    super.dispose();
  }

  @override
  Future<void> reloadTeam() => _initialLoad(_activeUserId);

  @override
  void refreshTeamMembers(UserModel user) {
    if (!teamMembers.any((m) => m.uid == user.uid)) {
      teamMembers.add(user);
    }
  }

  bool _isCurrentTeamRequest(int generation, String uid) =>
      mounted && _loadGeneration == generation && _activeUserId == uid;

  Future<void> _initialLoad([String? requestedUserId]) async {
    final uid = requestedUserId ?? _activeUserId;
    final generation = ++_loadGeneration;
    await _teamSubscription?.cancel();
    _teamSubscription = null;

    if (uid == null || uid != _activeUserId) return;
    if (mounted) {
      setState(() {
        _isLoadingMembers = true;
        _hasTeamLoadError = false;
      });
    }

    try {
      // Strict lookup preserves the distinction between a verified no-team state
      // and a membership/query failure that needs recovery.
      final team = await TeamRepository().getUserTeamStrict(uid);
      if (!_isCurrentTeamRequest(generation, uid)) return;

      if (team == null) {
        setState(() {
          localTeam = null;
          teamMembers.clear();
          _isLoadingMembers = false;
          _hasTeamLoadError = false;
        });
        return;
      }

      if (team.captainId.trim().isEmpty) {
        throw StateError('Team captain identity could not be verified');
      }

      setState(() {
        _teamNameController.text = team.name;
        _selectedSport = team.sportType;
        localTeam = team;
        teamMembers.clear();
        _isLoadingMembers = true;
        _hasTeamLoadError = false;
      });

      _teamSubscription = TeamRepository().streamTeam(team.id).listen((data) async {
        if (data.isEmpty || !_isCurrentTeamRequest(generation, uid)) return;
        try {
          final updatedTeam = await TeamRepository().getTeamStrict(team.id);
          if (updatedTeam == null || !_isCurrentTeamRequest(generation, uid)) return;
          if (updatedTeam.captainId.trim().isEmpty) {
            throw StateError('Team captain identity could not be verified');
          }
          setState(() {
            _teamNameController.text = updatedTeam.name;
            _selectedSport = updatedTeam.sportType;
            localTeam = updatedTeam;
          });
          await _loadMemberDetails(updatedTeam, generation, uid);
        } catch (err) {
          VSPLogger.w('Team realtime refresh could not be verified: $err');
          if (_isCurrentTeamRequest(generation, uid)) {
            setState(() {
              _hasTeamLoadError = true;
              _isLoadingMembers = false;
            });
          }
        }
      }, onError: (err) {
        VSPLogger.w('Team realtime stream notice: $err');
        if (_isCurrentTeamRequest(generation, uid)) {
          setState(() {
            _hasTeamLoadError = true;
            _isLoadingMembers = false;
          });
        }
      });

      await _loadMemberDetails(team, generation, uid);
    } catch (err, stackTrace) {
      VSPLogger.e('Team profile could not be verified', err, stackTrace);
      if (_isCurrentTeamRequest(generation, uid)) {
        setState(() {
          _hasTeamLoadError = true;
          _isLoadingMembers = false;
        });
      }
    }
  }

  Future<void> _loadMemberDetails(Team team, int generation, String uid) async {
    final memberIds = team.memberUids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id != team.captainId)
        .toSet()
        .toList();

    try {
      final members = await UserRepository().getUsersByIdsStrict(memberIds);
      if (!_isCurrentTeamRequest(generation, uid)) return;
      if (members.length != memberIds.length) {
        throw StateError('Team roster profiles could not all be verified');
      }
      setState(() {
        teamMembers
          ..clear()
          ..addAll(members);
        _isLoadingMembers = false;
        _hasTeamLoadError = false;
      });
    } catch (err, stackTrace) {
      VSPLogger.e('Team roster could not be verified', err, stackTrace);
      if (_isCurrentTeamRequest(generation, uid)) {
        setState(() {
          _hasTeamLoadError = true;
          _isLoadingMembers = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.id;

    if (uid == null) {
      return VSPScaffold(
        backgroundColor: VSPColors.background,
        body: SafeArea(
          child: VSPStateView(
            state: VSPUiState.error,
            title: isArabic ? 'تعذر التحقق من الحساب' : 'Account unavailable',
            message: isArabic
                ? 'سجّل الدخول مرة أخرى لعرض بيانات فريقك.'
                : 'Sign in again to view your team details.',
          ),
        ),
      );
    }

    if (_hasTeamLoadError) {
      return VSPScaffold(
        backgroundColor: VSPColors.background,
        body: SafeArea(
          child: VSPStateView(
            state: VSPUiState.error,
            title: isArabic ? 'تعذر تحميل بيانات الفريق' : 'Team data unavailable',
            message: isArabic
                ? 'تعذر التحقق من الفريق أو قائمة الأعضاء. أعد المحاولة قبل المتابعة.'
                : 'We could not verify your team or roster. Retry before continuing.',
            onRetry: () => _initialLoad(uid),
          ),
        ),
      );
    }

    if (_isLoadingMembers && localTeam == null) {
      return VSPScaffold(
        backgroundColor: VSPColors.background,
        body: SafeArea(
          child: VSPStateView(
            state: VSPUiState.loading,
            title: Localizations.localeOf(context).languageCode == 'ar' ? 'جارٍ تحميل فريقي' : 'Loading my team',
            message: Localizations.localeOf(context).languageCode == 'ar' ? 'نحدّث بيانات الفريق والأعضاء.' : 'Fetching team and member details.',
          ),
        ),
      );
    }

    final team = localTeam;
    final isCaptain = _isCaptain(team);

    return VSPScaffold(
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
      backgroundColor: VSPColors.transparent,
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
