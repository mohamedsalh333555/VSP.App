import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/storage_service.dart';
import 'dart:io';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/database_service.dart';
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
  
  bool _isCaptain(Team? currentTeam) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (currentTeam == null) return true; 
    return auth.currentUser?.uid == currentTeam.memberUids.first;
  }

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final team = await DatabaseService().getUserTeam(uid);
    if (mounted) {
      if (team != null) {
        _teamNameController.text = team.name;
        _selectedSport = team.sportType;
        _localTeam = team;
        await _loadMemberDetails(team);
      } else {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  Future<void> _loadMemberDetails(Team team) async {
    if (team.memberUids.length > 1) {
      final memberIds = team.memberUids.sublist(1);
      final members = await DatabaseService().getUsersByIds(memberIds);
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
          setState(() {
            if (!_teamMembers.any((m) => m.uid == user.uid)) {
              _teamMembers.add(user);
            }
          });

          if (currentTeam != null) {
            await DatabaseService().addMemberToTeam(
              currentTeam.id, 
              user.uid, 
              user.profileImageUrl ?? ''
            );
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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('teams')
          .where('memberUids', arrayContains: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _localTeam == null) {
          return const Scaffold(
            backgroundColor: VSPColors.background,
            body: Center(child: CircularProgressIndicator(color: VSPColors.accent)),
          );
        }

        Team? team;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final doc = snapshot.data!.docs.first;
          team = Team.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
          
          // Sync controllers once when team is first found or changed
          if (_localTeam?.id != team.id) {
             _teamNameController.text = team.name;
             _selectedSport = team.sportType;
             _localTeam = team;
             _loadMemberDetails(team); // Reload full member objects for chips
          }
        }

        final isCaptain = _isCaptain(team);

        return Scaffold(
          backgroundColor: VSPColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: VSPColors.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(l10n.myTeam, style: Theme.of(context).textTheme.displaySmall),
            actions: [
              if (team != null)
                IconButton(
                  icon: const Icon(Icons.share, color: VSPColors.accent),
                  onPressed: () {
                    SharingService.shareTeam(
                      context,
                      teamId: team!.id,
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCard(team?.points.toString() ?? '0', l10n.points, width: 80),
                    _buildStatCard((1 + _teamMembers.length).toString(), l10n.members, width: 80),
                    _buildStatCard(team?.championshipsWon.toString() ?? '0', l10n.trophies, width: 85),
                    _buildStatCard(team?.wins.toString() ?? '0', l10n.wins, width: 85),
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
                Row(
                  children: [
                    if (_selectedLogo != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: Image.file(File(_selectedLogo!.path), width: 50, height: 50, fit: BoxFit.cover),
                      )
                    else
                      ShimmerImage(
                        imageUrl: team?.logoUrl ?? '',
                        width: 50, height: 50, borderRadius: 25,
                        errorWidget: const Icon(Icons.groups, color: VSPColors.textSecondary),
                      ),
                    const SizedBox(width: VSPSpacing.md),
                    Expanded(
                      child: PrimaryButton(
                        text: l10n.uploadPhoto,
                        height: 45,
                        color: VSPColors.surfaceAlt,
                        textColor: isCaptain ? VSPColors.textPrimary : VSPColors.textSecondary.withValues(alpha: 0.5),
                        icon: Icons.cloud_upload_outlined,
                        onPressed: !isCaptain ? null : () async {
                          final picker = ImagePicker();
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                          if (image != null && mounted) setState(() => _selectedLogo = image);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: VSPSpacing.lg),

                // 4. Members Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.teamMembersHeader(1 + _teamMembers.length, 12), style: Theme.of(context).textTheme.bodyMedium),
                    if (isCaptain)
                      TextButton.icon(
                        onPressed: () => _showAddPlayerSheet(team),
                        icon: const Icon(Icons.add_circle_outline, size: 16, color: VSPColors.accent),
                        label: Text(l10n.addMember, style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: VSPSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(VSPSpacing.md),
                  decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg)),
                  child: _isLoadingMembers 
                    ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent)))
                    : (team == null && _teamMembers.isEmpty)
                        ? Center(child: Text(l10n.addMembersHint, style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.3), fontSize: 12)))
                        : Wrap(
                            spacing: 8, runSpacing: 8,
                            children: [
                              _buildMemberAvatar(team?.captainImageUrl ?? auth.userModel?.profileImageUrl ?? ''),
                              ..._teamMembers.map((member) => _buildMemberChip(member, team, isCaptain)),
                            ],
                          ),
                ),

                const SizedBox(height: VSPSpacing.xl),

                // 5. Achievements
                if (team != null) _buildAchievementSection(team) 
                else Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(l10n.registerTeamPrompt, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic)))),

                const SizedBox(height: VSPSpacing.xxl),

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
                else
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          text: l10n.deleteTeam,
                          color: VSPColors.error.withValues(alpha: 0.8),
                          textColor: VSPColors.textPrimary,
                          onPressed: !isCaptain ? null : () => _showDeleteConfirmation(team!),
                        ),
                      ),
                      const SizedBox(width: VSPSpacing.md),
                      Expanded(
                        child: PrimaryButton(
                          text: l10n.saveChanges,
                          isLoading: _isSaving,
                          onPressed: (_isSaving || !isCaptain) ? null : () => _handleUpdateTeam(team!),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: VSPSpacing.md),
              ],
            ),
          ),
        );
      },
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

      await DatabaseService().createTeam({
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

      await DatabaseService().updateTeam(team.id, {
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

  Widget _buildStatCard(String value, String label, {required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
        color: VSPColors.surface.withValues(alpha: 0.5),
      ),
      child: Column(
        children: [
           Text(value, style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24)),
           Text(label, textAlign: TextAlign.center, style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.8), fontSize: 9.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, {String? hint, bool readOnly = false}) {
    return Container(
      decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.md)),
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
        child: imageUrl.isEmpty ? const Icon(Icons.person, color: VSPColors.textSecondary, size: 18) : null,
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
              child: (user.profileImageUrl?.isEmpty ?? true) ? const Icon(Icons.person, color: VSPColors.textSecondary, size: 12) : null,
            ),
            const SizedBox(width: VSPSpacing.sm),
            Text(user.name ?? 'Player', style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
            if (isCaptain)
              GestureDetector(
                onTap: () async {
                  final userToRemove = user;
                  if (team != null) {
                    try {
                      await DatabaseService().removeMemberFromTeam(team.id, userToRemove.uid, userToRemove.profileImageUrl ?? '');
                      if (mounted) {
                        setState(() => _teamMembers.removeWhere((m) => m.uid == userToRemove.uid));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.memberRemovedSuccess), backgroundColor: VSPColors.accent),
                        );
                      }
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
                child: const Padding(padding: EdgeInsets.only(left: 6, right: 2), child: Icon(Icons.close, color: VSPColors.error, size: 14)),
              ),
        ],
      ),
    );
  }

  Widget _buildAchievementSection(Team team) {
    final l10n = AppLocalizations.of(context)!;
    final badges = [
      {'id': 'explorer', 'name': 'Explorer', 'icon': Icons.explore, 'desc': 'Play against 5 different teams'},
      {'id': 'gladiator', 'name': 'Gladiator', 'icon': Icons.security, 'desc': 'Played 10+ matches'},
      {'id': 'streak_3', 'name': 'Streak 3', 'icon': Icons.local_fire_department, 'desc': 'Won 3 matches in a row'},
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
                child: Row(children: [const Icon(Icons.bolt, color: VSPColors.warning, size: 14), const SizedBox(width: 4), Text(l10n.winStreak(team.currentWinningStreak), style: const TextStyle(color: VSPColors.warning, fontSize: 10, fontWeight: FontWeight.bold))]),
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
              final success = await DatabaseService().deleteTeam(team.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.teamDeletedSuccess), backgroundColor: VSPColors.error));
                Navigator.pop(context); 
              }
            })),
          ]),
        ],
      ),
    );
  }
}

