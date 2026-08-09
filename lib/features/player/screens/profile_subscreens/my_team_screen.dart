import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/storage_service.dart';
import 'dart:io';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/repositories/team_repository.dart';
import '../../../../core/repositories/user_repository.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../../data/models.dart';
import '../../widgets/add_player_sheet.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../core/services/sharing_service.dart';
import '../../../../core/utils/phone_utils.dart';

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
        _membershipSubscription = Supabase.instance.client
            .from('team_members')
            .stream(primaryKey: ['id'])
            .eq('user_id', uid)
            .listen((data) {
              _initialLoad();
            });
      }
    });
  }

  @override
  void dispose() {
    // 🛡️ SECURITY BARRIER: Rigorous Stream Subscription Cleanup
    // Cancel ALL Supabase Realtime subscriptions to prevent:
    // 1. Memory leaks from orphaned stream listeners
    // 2. Socket/WebSocket connection leaks exhausting Supabase free tier limits
    // 3. Potential DDOS-like behavior from accumulated zombie connections
    _teamSubscription?.cancel();
    _teamSubscription = null;
    _membershipSubscription?.cancel();
    _membershipSubscription = null;
    _teamNameController.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final team = await TeamRepository().getUserTeam(uid);
    if (mounted) {
      if (team != null) {
        _teamNameController.text = team.name;
        _selectedSport = team.sportType;
        _localTeam = team;
        
        // Listen to team updates in Supabase
        _teamSubscription?.cancel();
        _teamSubscription = Supabase.instance.client
            .from('teams')
            .stream(primaryKey: ['id'])
            .eq('id', team.id)
            .listen((data) async {
              if (data.isNotEmpty && mounted) {
                final updatedTeam = await DatabaseService().team.getTeam(team.id);
                if (updatedTeam != null && mounted) {
                  setState(() {
                    _teamNameController.text = updatedTeam.name;
                    _selectedSport = updatedTeam.sportType;
                    _localTeam = updatedTeam;
                  });
                }
              }
            });
        
        await _loadMemberDetails(team);
      } else {
        _teamSubscription?.cancel();
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
                user.profileImageUrl ?? ''
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
                      const Icon(LucideIcons.alertTriangle, color: VSPColors.error, size: 20),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: VSPColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.myTeam, style: Theme.of(context).textTheme.displaySmall),
        actions: [
          if (team != null)
            IconButton(
              icon: Icon(LucideIcons.share2, color: VSPColors.accent),
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
          MediaQuery.of(context).padding.bottom + 100 + MediaQuery.of(context).viewInsets.bottom
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Stats Grid
            Row(
              children: [
                Expanded(child: _buildStatCard(team?.points.toString() ?? '0', l10n.points)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard((1 + _teamMembers.length).toString(), l10n.members)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard(team?.championshipsWon.toString() ?? '0', l10n.trophies)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard(team?.wins.toString() ?? '0', l10n.wins)),
              ],
            ),

            const SizedBox(height: VSPSpacing.lg),

            // 2. Team Profile Section
            Text(l10n.teamName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: VSPSpacing.sm),
            _buildTextField(_teamNameController, hint: l10n.enterTeamName, readOnly: !isCaptain),

            const SizedBox(height: VSPSpacing.md),

            Text(l10n.sportsType, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: VSPSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.md)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSport,
                  isExpanded: true,
                  dropdownColor: VSPColors.surface,
                  items: VSPConstants.sports.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: VSPColors.textPrimary)))).toList(),
                  onChanged: !isCaptain ? null : (val) => setState(() => _selectedSport = val!),
                ),
              ),
            ),

            const SizedBox(height: VSPSpacing.lg),

            // 3. Logo Upload
            Builder(builder: (_) {
              final hasLogo = _selectedLogo != null || (team?.logoUrl.isNotEmpty ?? false);
              final uploadBtn = PrimaryButton(
                text: l10n.uploadPhoto,
                height: 45,
                color: VSPColors.surfaceAlt,
                textColor: isCaptain ? VSPColors.textPrimary : VSPColors.textSecondary.withValues(alpha: 0.5),
                icon: LucideIcons.uploadCloud,
                onPressed: !isCaptain ? null : () async {
                  final picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                  if (image != null && mounted) setState(() => _selectedLogo = image);
                },
              );
              if (!hasLogo) return SizedBox(width: double.infinity, child: uploadBtn);
              return Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: _selectedLogo != null
                        ? Image.file(File(_selectedLogo!.path), width: 50, height: 50, fit: BoxFit.cover)
                        : ShimmerImage(imageUrl: team?.logoUrl ?? '', width: 50, height: 50, borderRadius: 25),
                  ),
                  const SizedBox(width: VSPSpacing.md),
                  Expanded(child: uploadBtn),
                ],
              );
            }),

            const SizedBox(height: VSPSpacing.lg),

            // 4. Members Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.teamMembersHeader(1 + _teamMembers.length, 12), style: Theme.of(context).textTheme.bodyMedium),
                if (isCaptain && (1 + _teamMembers.length) < 12)
                  TextButton.icon(
                    onPressed: () => _showAddPlayerSheet(team),
                    icon: Icon(LucideIcons.plusCircle, size: 16, color: VSPColors.accent),
                    label: Text(l10n.addMember, style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: VSPSpacing.sm),
            if (_isLoadingMembers)
              const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent)))
            else if (_teamMembers.isNotEmpty || team != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(VSPSpacing.md),
                decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg)),
                child: Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _buildMemberAvatar(team?.captainImageUrl ?? auth.userModel?.profileImageUrl ?? ''),
                    ..._teamMembers.map((member) => _buildMemberChip(member, team, isCaptain)),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(l10n.addMembersHint, style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.5), fontSize: 12)),
              ),

            const SizedBox(height: VSPSpacing.lg),

            // 5. Achievements
            if (team != null) _buildAchievementSection(team),

            const SizedBox(height: VSPSpacing.lg),

            // 6. Action Buttons
            if (team == null)
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: l10n.createTeam,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : () => _handleCreateTeam(auth.userModel),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      text: l10n.deleteTeam,
                      color: VSPColors.error.withValues(alpha: 0.8),
                      textColor: VSPColors.textPrimary,
                      onPressed: !isCaptain ? null : () => _showDeleteConfirmation(team),
                    ),
                  ),
                  const SizedBox(width: VSPSpacing.md),
                  Expanded(
                    child: PrimaryButton(
                      text: l10n.saveChanges,
                      isLoading: _isSaving,
                      onPressed: (_isSaving || !isCaptain) ? null : () => _handleUpdateTeam(team),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: VSPSpacing.md),
              if (!isCaptain) SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: "مغادرة الفريق",
                  color: VSPColors.error.withValues(alpha: 0.15),
                  textColor: VSPColors.error,
                  onPressed: () => _showLeaveConfirmation(team, uid),
                ),
              ),
            ],
            const SizedBox(height: VSPSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreateTeam(UserModel? user) async {
    final l10n = AppLocalizations.of(context)!;
    if (_teamNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.enterTeamNameError), backgroundColor: VSPColors.error));
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

      await TeamRepository().createTeam({
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.teamCreatedSuccess), backgroundColor: VSPColors.accent));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorOccurred(e.toString())), backgroundColor: VSPColors.error));
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
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.teamUpdatedSuccess), backgroundColor: VSPColors.accent));
         setState(() => _selectedLogo = null);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorOccurred(e.toString())), backgroundColor: VSPColors.error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
        color: VSPColors.surface.withValues(alpha: 0.5),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, {String? hint, bool readOnly = false}) {
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider.withValues(alpha: 0.6)),
      ),
      child: TextField(
        controller: controller, readOnly: readOnly,
        style: const TextStyle(color: VSPColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.5), fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(String imageUrl) {
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: VSPColors.accent, width: 2)),
      child: CircleAvatar(
        radius: 17, backgroundColor: VSPColors.surfaceAlt,
        backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
        child: imageUrl.isEmpty ? Icon(LucideIcons.user, color: VSPColors.textSecondary, size: 18) : null,
      ),
    );
  }

  Widget _buildMemberChip(UserModel user, Team? team, bool isCaptain) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: VSPColors.surfaceAlt, borderRadius: BorderRadius.circular(20), border: Border.all(color: VSPColors.divider)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
            CircleAvatar(
              radius: 12, backgroundColor: VSPColors.surface,
              backgroundImage: (user.profileImageUrl?.isNotEmpty ?? false) ? NetworkImage(user.profileImageUrl!) : null,
              child: (user.profileImageUrl?.isEmpty ?? true) ? Icon(LucideIcons.user, color: VSPColors.textSecondary, size: 12) : null,
            ),
            const SizedBox(width: VSPSpacing.sm),
            Text(user.name ?? 'Player', style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
            if (isCaptain && (1 + _teamMembers.length) < 12)
              GestureDetector(
                onTap: () async {
                  final userToRemove = user;
                  if (team != null) {
                    try {
                      await TeamRepository().removeMemberFromTeam(team.id, userToRemove.uid, userToRemove.profileImageUrl ?? '');
                      if (!mounted) return;
                      setState(() => _teamMembers.removeWhere((m) => m.uid == userToRemove.uid));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.memberRemovedSuccess), backgroundColor: VSPColors.accent),
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
                    setState(() => _teamMembers.removeWhere((m) => m.uid == userToRemove.uid));
                  }
                },
                child: const Padding(padding: EdgeInsets.only(left: 6, right: 2), child: Icon(LucideIcons.x, color: VSPColors.error, size: 14)),
              ),
        ],
      ),
    );
  }

  Widget _buildAchievementSection(Team team) {
    final l10n = AppLocalizations.of(context)!;
    final badges = [
      {'id': 'explorer', 'name': 'Explorer', 'icon': LucideIcons.compass, 'desc': 'Play against 5 different teams'},
      {'id': 'gladiator', 'name': 'Gladiator', 'icon': LucideIcons.shield, 'desc': 'Played 10+ matches'},
      {'id': 'streak_3', 'name': 'Streak 3', 'icon': LucideIcons.flame, 'desc': 'Won 3 matches in a row'},
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
                decoration: BoxDecoration(color: VSPColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: VSPColors.warning.withValues(alpha: 0.5))),
                child: Row(children: [Icon(LucideIcons.zap, color: VSPColors.warning, size: 14), const SizedBox(width: 4), Text(l10n.winStreak(team.currentWinningStreak), style: const TextStyle(color: VSPColors.warning, fontSize: 10, fontWeight: FontWeight.bold))]),
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
              return GestureDetector(
                onTap: () => _showBadgeInfo(badge['name'] as String, badge['desc'] as String, isUnlocked),
                child: Column(
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: isUnlocked ? VSPColors.accent.withValues(alpha: 0.1) : VSPColors.surfaceAlt.withValues(alpha: 0.5),
                        border: Border.all(color: isUnlocked ? VSPColors.accent : VSPColors.divider, width: 2),
                        boxShadow: isUnlocked ? VSPShadow.subtle : [],
                      ),
                      child: Icon(badge['icon'] as IconData, color: isUnlocked ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.3), size: 30),
                    ),
                    const SizedBox(height: VSPSpacing.sm),
                    Text(badge['name'] as String, style: TextStyle(color: isUnlocked ? VSPColors.textPrimary : VSPColors.textSecondary.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showBadgeInfo(String name, String desc, bool isUnlocked) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(name, style: TextStyle(color: isUnlocked ? VSPColors.accent : VSPColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(desc, style: const TextStyle(color: VSPColors.textSecondary)),
            const SizedBox(height: VSPSpacing.md),
            Text(isUnlocked ? l10n.badgeUnlockedStatus : l10n.badgeLockedStatus, style: TextStyle(color: isUnlocked ? VSPColors.accent : VSPColors.error, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [PrimaryButton(text: l10n.gotItBtn, height: 48, onPressed: () => Navigator.pop(context))],
      ),
    );
  }

  void _showLeaveConfirmation(Team team, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: const Text('مغادرة الفريق', style: TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من رغبتك في مغادرة هذا الفريق؟'),
        actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          Row(children: [
            Expanded(child: PrimaryButton(text: 'إلغاء', height: 48, color: VSPColors.surfaceAlt, textColor: VSPColors.textPrimary, onPressed: () => Navigator.pop(context))),
            const SizedBox(width: VSPSpacing.md),
            Expanded(child: PrimaryButton(text: 'تأكيد المغادرة', height: 48, color: VSPColors.error, textColor: Colors.white, onPressed: () async {
              Navigator.pop(context);
              setState(() => _isSaving = true);
              try {
                await TeamRepository().removeMemberFromTeam(team.id, userId, '');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت مغادرة الفريق بنجاح.'), backgroundColor: VSPColors.success));
                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                final errorMsg = e.toString().replaceAll('Exception:', '').trim();
                final displayMsg = errorMsg == 'active_match_or_tournament_error'
                    ? AppLocalizations.of(context)!.teamMemberDeleteLockError
                    : errorMsg;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(displayMsg), backgroundColor: VSPColors.error));
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            })),
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
            Expanded(child: PrimaryButton(text: l10n.cancel, height: 48, color: VSPColors.surfaceAlt, textColor: VSPColors.textPrimary, onPressed: () => Navigator.pop(context))),
            const SizedBox(width: VSPSpacing.md),
            Expanded(child: PrimaryButton(text: l10n.delete, height: 48, color: VSPColors.error, textColor: VSPColors.background, onPressed: () async {
              Navigator.pop(context);
              try {
                final success = await TeamRepository().deleteTeam(team.id);
                if (!context.mounted) return;
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.teamDeletedSuccess), backgroundColor: VSPColors.error));
                  if (!context.mounted) return;
                  Navigator.pop(context);
                }
              } catch(e) {
                if (!context.mounted) return;
                final isAr = Localizations.localeOf(context).languageCode == 'ar';
                final errStr = e.toString();
                String msg = isAr ? 'حدث خطأ أثناء حذف الفريق' : 'Error deleting team';
                if (errStr.contains('active_match_or_tournament_error') || errStr.contains('team_in_tournament')) {
                  msg = isAr
                      ? 'لا يمكن حذف الفريق لوجود مباريات قادمة أو بطولة نشطة! ⚠️'
                      : 'Cannot delete team with upcoming matches or active tournament! ⚠️';
                }
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: VSPColors.error));
              }
            })),
          ]),
        ],
      ),
    );
  }
}



