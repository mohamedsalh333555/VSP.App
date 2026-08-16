import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/copyable_phone_text.dart';
import '../../../data/models.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/shimmer_image.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/utils/vsp_feedback.dart';

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

  Team get team => widget.team ?? _fetchedTeam!;

  @override
  void initState() {
    super.initState();
    final currentTeamId = widget.team?.id ?? widget.teamId;
    if (currentTeamId != null) {
      _check1v1Champion(currentTeamId);
    }
    if (widget.team != null) {
      _loadMemberDetails();
    } else if (widget.teamId != null) {
      _loadTeamAndMembers();
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

  void _contactCaptain() async {
    final phone = team.captainPhone;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    if (phone == null || phone.trim().isEmpty) {
      VSPFeedback.showError(
        context,
        isArabic ? 'رقم هاتف كابتن الفريق غير متوفر حالياً 📞' : 'Captain phone number is not available',
      );
      return;
    }

    final message = isArabic
        ? 'مرحباً كابتن ${team.captainName}، رأيت فريقك ${team.name} على تطبيق VSP وأود التواصل معك.'
        : 'Hello Captain ${team.captainName}, I saw your team ${team.name} on VSP and would like to contact you.';
        
    final encodedMessage = Uri.encodeComponent(message);
    final url = 'https://wa.me/$phone?text=$encodedMessage';

    try {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Could not launch WhatsApp chat: $e');
    }
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
          child: Text('Team not found ⚽', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(isArabic ? Iconsax.arrow_right_3_copy : Iconsax.arrow_left_2_copy, color: VSPColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
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
            Center(
              child: Column(
                children: [
                  ShimmerImage(
                    imageUrl: team.logoUrl,
                    width: 100,
                    height: 100,
                    borderRadius: 50,
                    errorWidget: const CircleAvatar(
                      radius: 50,
                      backgroundColor: VSPColors.surface,
                      child: Icon(Iconsax.people_copy, color: VSPColors.textSecondary, size: 40),
                    ),
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  Text(
                    team.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: VSPSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${team.governorate} • ${team.sportType}',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: VSPSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      team.rankTitle,
                      style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_has1v1Champion) ...[
                    const SizedBox(height: VSPSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: VSPColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: VSPColors.warning, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: VSPColors.warning.withValues(alpha: 0.25),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Text(
                        '👑 يضم بطل 1 ضد 1',
                        style: TextStyle(
                          color: VSPColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 2. Stats Grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard(team.points.toString(), l10n.points),
                _buildStatCard((1 + _teamMembers.length).toString(), l10n.members),
                _buildStatCard(team.championshipsWon.toString(), l10n.trophies),
                _buildStatCard(team.wins.toString(), l10n.wins),
              ],
            ),

            const SizedBox(height: 32),

            // 3. Captain Info
            Text(isArabic ? 'كابتن الفريق' : 'Team Captain', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: VSPSpacing.sm),
            VSPCard(
              padding: const EdgeInsets.all(VSPSpacing.md),
              margin: EdgeInsets.zero,
              color: VSPColors.surface,
              child: Row(
                children: [
                  ShimmerImage(
                    imageUrl: team.captainImageUrl,
                    width: 48,
                    height: 48,
                    borderRadius: 24,
                    errorWidget: const CircleAvatar(
                      radius: 24,
                      backgroundColor: VSPColors.surfaceAlt,
                      child: Icon(Iconsax.user_copy, color: VSPColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: VSPSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(team.captainName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(isArabic ? 'المدير الفني / كابتن' : 'Manager / Captain', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
                        if (team.captainPhone != null && team.captainPhone!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          CopyablePhoneText(
                            phone: team.captainPhone!,
                            style: const TextStyle(color: VSPColors.accent, fontSize: 12, decoration: TextDecoration.underline),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (team.captainPhone != null && team.captainPhone!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Iconsax.messages_3_copy, color: VSPColors.accent),
                      onPressed: _contactCaptain,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 4. Team Roster
            Text(isArabic ? 'قائمة اللاعبين' : 'Team Roster', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: VSPSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(VSPSpacing.md),
              decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg)),
              child: _isLoadingMembers
                  ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent)))
                  : _teamMembers.isEmpty
                      ? Center(
                          child: Text(
                            isArabic ? 'لا يوجد أعضاء مضافين حالياً' : 'No team members added yet',
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _teamMembers.map((member) => _buildMemberChip(member)).toList(),
                        ),
            ),

            const SizedBox(height: 32),

            // 5. Achievements
            _buildAchievementSection(),

            const SizedBox(height: 48),

            // 6. Action Button (Challenge)
            if (team.captainPhone != null && team.captainPhone!.isNotEmpty)
              PrimaryButton(
                text: isArabic ? 'تحدي هذا الفريق ⚽' : 'Challenge Team ⚽',
                onPressed: _contactCaptain,
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
        color: VSPColors.surface.withValues(alpha: 0.5),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberChip(UserModel user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: VSPColors.surface,
            backgroundImage: (user.profileImageUrl?.isNotEmpty ?? false) ? NetworkImage(user.profileImageUrl!) : null,
            child: (user.profileImageUrl?.isEmpty ?? true) ? const Icon(Iconsax.user_copy, color: VSPColors.textSecondary, size: 10) : null,
          ),
          const SizedBox(width: 6),
          Text(user.name ?? 'Player', style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAchievementSection() {
    final l10n = AppLocalizations.of(context)!;
    final badges = [
      {'id': 'explorer', 'name': 'Explorer', 'icon': Iconsax.discover_copy, 'desc': 'Play against 5 different teams'},
      {'id': 'gladiator', 'name': 'Gladiator', 'icon': Iconsax.security_safe_copy, 'desc': 'Played 10+ matches'},
      {'id': 'streak_3', 'name': 'Streak 3', 'icon': Iconsax.flash_1_copy, 'desc': 'Won 3 matches in a row'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.teamAchievements, style: Theme.of(context).textTheme.titleLarge),
            if (team.currentWinningStreak > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VSPColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: VSPColors.warning.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.flash_1_copy, color: VSPColors.warning, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      l10n.winStreak(team.currentWinningStreak),
                      style: const TextStyle(color: VSPColors.warning, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: VSPSpacing.md),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 20),
            itemBuilder: (context, index) {
              final badge = badges[index];
              final isUnlocked = team.unlockedBadges.contains(badge['id']);
              return Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isUnlocked ? VSPColors.accent.withValues(alpha: 0.1) : VSPColors.surfaceAlt.withValues(alpha: 0.5),
                      border: Border.all(color: isUnlocked ? VSPColors.accent : VSPColors.divider, width: 2),
                    ),
                    child: Icon(
                      badge['icon'] as IconData,
                      color: isUnlocked ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.3),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: VSPSpacing.sm),
                  Text(
                    badge['name'] as String,
                    style: TextStyle(
                      color: isUnlocked ? VSPColors.textPrimary : VSPColors.textSecondary.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
