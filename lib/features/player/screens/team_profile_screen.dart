import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../core/repositories/matchup_repository.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/utils/vsp_launcher_utils.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../widgets/team_profile/team_profile_hero_header.dart';
import '../widgets/team_profile/team_profile_stats_grid.dart';
import '../widgets/team_profile/team_profile_captain_card.dart';
import '../widgets/team_profile/team_profile_roster_section.dart';
import '../widgets/team_profile/team_profile_achievements_section.dart';
import '../widgets/team_profile/team_profile_head_to_head_section.dart';
import '../widgets/team_profile/team_profile_action_bar.dart';
import '../widgets/team_profile/team_matchup_invite_modal.dart';

class TeamProfileScreen extends StatefulWidget {
  final Team? team;
  final String? teamId;

  const TeamProfileScreen({
    super.key,
    this.team,
    this.teamId,
  });

  @override
  State<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends State<TeamProfileScreen> {
  final List<UserModel> _teamMembers = [];
  bool _isLoadingMembers = true;
  Team? _fetchedTeam;
  bool _isLoadingTeam = false;
  bool _has1v1Champion = false;
  List<Map<String, dynamic>> _headToHeadRecords = [];
  bool _isGeneratingCode = false;

  Team get team => widget.team ?? _fetchedTeam!;

  @override
  void initState() {
    super.initState();
    final currentTeamId = widget.team?.id ?? widget.teamId;
    if (currentTeamId != null) {
      _check1v1Champion(currentTeamId);
      _loadHeadToHead(currentTeamId);
    }
    if (widget.team != null) {
      _loadMemberDetails();
    } else if (widget.teamId != null) {
      _loadTeamAndMembers();
    }
  }

  Future<void> _loadHeadToHead(String teamId) async {
    try {
      final records = await MatchupRepository().getAllHeadToHeadForTeam(teamId);
      if (mounted) {
        setState(() {
          _headToHeadRecords = records;
        });
      }
    } catch (e) {
      debugPrint('Error loading head to head: $e');
    }
  }

  Future<void> _check1v1Champion(String teamId) async {
    try {
      final hasChamp = await TeamRepository().has1v1Champion(teamId);
      if (mounted) {
        setState(() {
          _has1v1Champion = hasChamp;
        });
      }
    } catch (e) {
      debugPrint('Error checking 1v1 champion in team profile: $e');
    }
  }

  Future<void> _loadTeamAndMembers() async {
    setState(() {
      _isLoadingTeam = true;
    });
    try {
      final t = await TeamRepository().getTeam(widget.teamId!);
      if (mounted) {
        setState(() {
          _fetchedTeam = t;
          _isLoadingTeam = false;
        });
        if (t != null) {
          _loadMemberDetails();
        }
      }
    } catch (e) {
      debugPrint('Error loading team: $e');
      if (mounted) {
        setState(() {
          _isLoadingTeam = false;
        });
      }
    }
  }

  Future<void> _loadMemberDetails() async {
    if (team.memberUids.length > 1) {
      final memberIds = team.memberUids.sublist(1);
      try {
        final members = await UserRepository().getUsersByIds(memberIds);
        if (mounted) {
          setState(() {
            _teamMembers.clear();
            _teamMembers.addAll(members);
            _isLoadingMembers = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading team members: $e');
        if (mounted) setState(() => _isLoadingMembers = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _generateMatchupInviteCode() async {
    setState(() => _isGeneratingCode = true);
    try {
      final res = await MatchupRepository().generateTeamInviteCode(team.id);
      final code = res['invite_code']?.toString() ?? '';

      if (!mounted) return;

      await showTeamMatchupInviteModal(context, code);
    } catch (e) {
      debugPrint('Error generating invite code: $e');
      if (mounted) {
        VSPFeedback.showError(context, 'تعذر توليد كود الدعوة: $e');
      }
    } finally {
      if (mounted) setState(() => _isGeneratingCode = false);
    }
  }

  void _contactCaptain() async {
    final phone = team.captainPhone;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (phone == null || phone.trim().isEmpty) {
      VSPFeedback.showError(
        context,
        isArabic ? 'رقم هاتف كابتن الفريق غير متوفر حالياً ' : 'Captain phone number is not available',
      );
      return;
    }

    final message = isArabic
        ? 'مرحباً كابتن ${team.captainName}، رأيت فريقك ${team.name} على تطبيق VSP وأود التواصل معك.'
        : 'Hello Captain ${team.captainName}, I saw your team ${team.name} on VSP and would like to contact you.';

    await VSPLauncherUtils.openWhatsApp(
      context,
      phone: phone,
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTeam) {
      return const Scaffold(
        backgroundColor: VSPColors.background,
        body: Center(
          child: CircularProgressIndicator(color: VSPColors.accent),
        ),
      );
    }

    if (widget.team == null && _fetchedTeam == null) {
      return const Scaffold(
        backgroundColor: VSPColors.background,
        body: Center(
          child: Text('Team not found ', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final currentUid = auth.currentUser?.uid;
    final isCaptain = currentUid != null &&
        (currentUid == team.captainId || (team.memberUids.isNotEmpty && team.memberUids.first == currentUid));

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const VSPBackButton(),
        title: Text(isArabic ? 'ملف الفريق' : 'Team Profile', style: Theme.of(context).textTheme.displaySmall),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(VSPSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Team Hero Header
            TeamProfileHeroHeader(
              team: team,
              has1v1Champion: _has1v1Champion,
            ),

            if (team.bio.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.card),
                  border: Border.all(color: VSPColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isArabic ? 'نبذة عن الفريق' : 'About the team',
                        style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(team.bio,
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12.5, height: 1.5)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // 2. Stats Grid
            TeamProfileStatsGrid(
              team: team,
              totalMembersCount: 1 + _teamMembers.length,
            ),

            const SizedBox(height: 32),

            // 3. Captain Info
            TeamProfileCaptainCard(
              team: team,
              onContactCaptain: _contactCaptain,
            ),

            const SizedBox(height: 32),

            // 4. Team Roster
            TeamProfileRosterSection(
              members: _teamMembers,
              isLoading: _isLoadingMembers,
            ),

            const SizedBox(height: 32),

            // 5. Achievements
            TeamProfileAchievementsSection(team: team),

            // 6. Head to Head History
            if (_headToHeadRecords.isNotEmpty) ...[
              const SizedBox(height: 32),
              TeamProfileHeadToHeadSection(
                team: team,
                headToHeadRecords: _headToHeadRecords,
              ),
            ],

            const SizedBox(height: 32),

            // 7. Action Button (Generate Matchup Code for Captain OR Challenge)
            TeamProfileActionBar(
              team: team,
              isCaptain: isCaptain,
              isGeneratingCode: _isGeneratingCode,
              onGenerateCode: _generateMatchupInviteCode,
              onChallengeTeam: _contactCaptain,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
