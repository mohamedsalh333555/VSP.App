import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/cloudinary_service.dart';
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
  Team? _myTeam;
  bool _isLoading = true;
  String? _newLogoUrl;
  bool _isSaving = false;
  XFile? _selectedLogo; // 🖼️ Deferred upload: only upload on save
  
  // ✅ Permission Check: Captain is always index 0 of the team's member list
  bool get isCaptain {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (_myTeam == null) return true; // Creator is captain by default
    return auth.currentUser?.uid == _myTeam!.memberUids.first;
  }

  @override
  void initState() {
    super.initState();
    _fetchMyTeam();
  }

  Future<void> _fetchMyTeam() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.uid;
    
    if (uid != null) {
      // BETA READY: Unified fetch for Captain OR Member by UID
      final team = await DatabaseService().getUserTeam(uid);
      if (mounted) {
        // Load member details for chips
        List<UserModel> members = [];
        if (team != null && team.memberUids.length > 1) {
          // IDs from 1 to end (excluding captain)
          final memberIds = team.memberUids.sublist(1);
          members = await DatabaseService().getUsersByIds(memberIds);
        }

        setState(() {
          _myTeam = team;
          if (team != null) {
            _teamNameController.text = team.name;
            _selectedSport = team.sportType;
          }
          _teamMembers.clear();
          _teamMembers.addAll(members);
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddPlayerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPlayerSheet(
        existingMemberUids: [
           _myTeam?.memberUids.first ?? '', 
           ..._teamMembers.map((m) => m.uid)
        ],
        onPlayerAdded: (UserModel user) async {
          setState(() {
            if (!_teamMembers.any((m) => m.uid == user.uid)) {
              _teamMembers.add(user);
            }
          });

          // If team exists, update Firestore immediately
          if (_myTeam != null) {
            await DatabaseService().addMemberToTeam(
              _myTeam!.id, 
              user.uid, 
              user.profileImageUrl ?? ''
            );
            _fetchMyTeam(); // Refresh state
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Team',
          style: Theme.of(context).textTheme.displaySmall, // Unified Typography
        ),
        actions: [
          if (_myTeam != null)
            IconButton(
              icon: const Icon(Icons.share, color: VSPColors.accent),
              onPressed: () {
                SharingService.shareTeam(
                  context,
                  teamId: _myTeam!.id,
                  teamName: _myTeam!.name,
                  governorate: _myTeam!.governorate,
                );
              },
            ),
          const SizedBox(width: 8),
        ],
        centerTitle: true,
      ),
      // ✅ FIX: Show Loader while fetching data, preventing blank screen/errors
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: VSPColors.accent),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(), // ✅ Add Scroll Physics
              padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, MediaQuery.of(context).padding.bottom + 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatCard(
                          _myTeam?.points.toString() ?? '0', 'Points',
                          width: 80),
                      _buildStatCard(
                          (1 + _teamMembers.length).toString(),
                          'Members',
                          width: 80),
                      _buildStatCard(
                          _myTeam?.championshipsWon.toString() ?? '0',
                          'Trophies',
                          width: 85),
                      _buildStatCard(
                          _myTeam?.wins.toString() ?? '0', 'Wins',
                          width: 85),
                    ],
                  ),

                  const SizedBox(height: VSPSpacing.lg),

                  // Team Name
                  Text(
                    'Team Name',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: VSPSpacing.sm),
                  _buildTextField(
                    _teamNameController, 
                    hint: 'Enter your team name',
                    readOnly: !isCaptain,
                  ),

                  const SizedBox(height: VSPSpacing.md),

                  // Sports Type
                  Text(
                    'Sports Type',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: VSPSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSport,
                        isExpanded: true,
                        dropdownColor: VSPColors.surface,
                        items: VSPConstants.sports
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s, style: const TextStyle(color: VSPColors.textPrimary)),
                                ))
                            .toList(),
                        onChanged: !isCaptain ? null : (val) => setState(() => _selectedSport = val!),
                      ),
                    ),
                  ),

                  const SizedBox(height: VSPSpacing.lg),

                  // Team Logo & Upload
                  Row(
                    children: [
                      ShimmerImage(
                        imageUrl:
                            _newLogoUrl ?? _myTeam?.logoUrl ?? '',
                        width: 50,
                        height: 50,
                        borderRadius: 25,
                        errorWidget: const Icon(Icons.person,
                            color: VSPColors.textSecondary),
                      ),
                      const SizedBox(width: VSPSpacing.md),
                      // ✅ Use VSPPrimaryButton or styled ElevatedButton
                      Expanded(
                        child: PrimaryButton(
                          text: 'Upload Photo',
                          height: 45,
                          color: VSPColors.surfaceAlt,
                          textColor: isCaptain ? VSPColors.textPrimary : VSPColors.textSecondary.withValues(alpha: 0.5),
                          icon: Icons.cloud_upload_outlined,
                          onPressed: !isCaptain ? null : () async {
                            final picker = ImagePicker();
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 70,
                            );
                            if (image != null && mounted) {
                              setState(() => _selectedLogo = image);
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: VSPSpacing.lg),

                  // Members Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Team Members (${1 + _teamMembers.length}/12)',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (isCaptain)
                        TextButton.icon(
                          onPressed: _showAddPlayerSheet,
                          icon: const Icon(Icons.add_circle_outline,
                              size: 16, color: VSPColors.accent),
                          label: const Text('Add Member',
                              style: TextStyle(
                                  color: VSPColors.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: VSPSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(VSPSpacing.md),
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(VSPRadius.lg),
                    ),
                    child: (_myTeam == null && _teamMembers.isEmpty)
                        ? Center(
                            child: Text('Add your team members',
                                style: TextStyle(
                                    color: VSPColors.textSecondary.withValues(alpha: 0.3),
                                    fontSize: 12)))
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              // Captain Avatar (Static personal image)
                              if (_myTeam != null)
                                _buildMemberAvatar(_myTeam?.captainImageUrl ?? '')
                              else if (Provider.of<AuthProvider>(context, listen: false).userModel != null)
                                _buildMemberAvatar(Provider.of<AuthProvider>(context, listen: false).userModel!.profileImageUrl ?? ''),
                                
                              // Show team members as chips
                              ..._teamMembers
                                  .map((member) => _buildMemberChip(member)),
                            ],
                          ),
                  ),

                  const SizedBox(height: VSPSpacing.xl),

                  if (_myTeam != null)
                    _buildAchievementSection(_myTeam!)
                  else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          "Register your team to start unlocking achievements!",
                          style: TextStyle(
                              color: VSPColors.textSecondary,
                              fontSize: 13,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    ),

                  const SizedBox(height: VSPSpacing.xxl),

                  // Buttons
                  if (_myTeam == null)
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        text: 'Create Team',
                        isLoading: _isSaving,
                        onPressed: _isSaving ? null : () async {
                          if (_teamNameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a team name'), backgroundColor: VSPColors.error),
                            );
                            return;
                          }

                          setState(() => _isSaving = true);
                          try {
                            final auth = Provider.of<AuthProvider>(context, listen: false);
                            final user = auth.userModel;
                            
                            if (user == null) throw 'User session expired';

                            // 🖼️ Deferred upload: upload logo only on save
                            String? logoUrl = _newLogoUrl;
                            if (_selectedLogo != null) {
                              logoUrl = await CloudinaryService().uploadImage(
                                _selectedLogo!,
                                folder: 'teams/${user.uid}/logo',
                              );
                            }

                            // Construct initial arrays - start with Captain
                            List<String> finalUids = [user.uid];
                            List<String> finalImages = [user.profileImageUrl ?? '']; // Captain face, NOT logo

                            // Add players currently active in the UI (_teamMembers)
                            for (var member in _teamMembers) {
                              finalUids.add(member.uid);
                              finalImages.add(member.profileImageUrl ?? '');
                            }

                            final teamId = await DatabaseService().createTeam({
                              'name': _teamNameController.text.trim(),
                              'sportType': _selectedSport,
                              'captainName': user.name ?? 'Captain',
                              'captainImageUrl': user.profileImageUrl ?? '', // Captain's personal image
                              'logoUrl': logoUrl ?? '', // Team's logo
                              'captainPhone': PhoneUtils.normalize(user.phone ?? ''),
                              'memberUids': finalUids,
                              'playerImages': finalImages,
                              'playersCount': finalUids.length,
                              'governorate': user.governorate ?? 'Cairo',
                              'stadium': 'TBD',
                              'date': 'Upcoming',
                            });

                            if (teamId != null && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Team created successfully!'), backgroundColor: VSPColors.accent),
                              );
                              setState(() => _teamMembers.clear());
                              await _fetchMyTeam();
                            }
                          } catch (e) {
                             if (mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(content: Text('Error: $e'), backgroundColor: VSPColors.error),
                               );
                             }
                          } finally {
                            if (mounted) setState(() => _isSaving = false);
                          }
                        },
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            text: 'Delete Team',
                            color: VSPColors.error.withValues(alpha: 0.8),
                            textColor: VSPColors.textPrimary,
                            onPressed: !isCaptain ? null : () {
                              _showDeleteConfirmation(context);
                            },
                          ),
                        ),
                        const SizedBox(width: VSPSpacing.md),
                        Expanded(
                          child: PrimaryButton(
                            text: 'Save Changes',
                            isLoading: _isSaving,
                            onPressed: (_isSaving || !isCaptain)
                                ? null
                                : () async {
                                    setState(() => _isSaving = true);

                                    try {
                                      // 🖼️ Deferred upload: upload logo only on save
                                      final user = Provider.of<AuthProvider>(context, listen: false).userModel;
                                      String? logoUrl = _newLogoUrl;
                                      if (_selectedLogo != null) {
                                        logoUrl = await CloudinaryService().uploadImage(
                                          _selectedLogo!,
                                          folder: 'teams/${user?.uid ?? 'unknown'}/logo',
                                        );
                                      }

                                      // REFACTOR: Create clean lists starting with Captain (Index 0)
                                      List<String> finalUids = [_myTeam!.memberUids.first];
                                      List<String> finalImages = [user?.profileImageUrl ?? _myTeam!.playerImages.first];

                                      for (var member in _teamMembers) {
                                        finalUids.add(member.uid);
                                        finalImages.add(member.profileImageUrl ?? '');
                                      }

                                      final success = await DatabaseService().updateTeam(_myTeam!.id, {
                                        'name': _teamNameController.text,
                                        'sportType': _selectedSport,
                                        'logoUrl': logoUrl ?? _myTeam!.logoUrl,
                                        'captainImageUrl': user?.profileImageUrl ?? _myTeam!.captainImageUrl,
                                        'memberUids': finalUids,
                                        'playerImages': finalImages,
                                        'playersCount': finalUids.length,
                                      });

                                      if (success && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Team updated successfully!'),
                                            backgroundColor: VSPColors.accent,
                                          ),
                                        );
                                        setState(() => _teamMembers.clear());
                                        await _fetchMyTeam();
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e'), backgroundColor: VSPColors.error),
                                        );
                                      }
                                    } finally {
                                      if (mounted) setState(() => _isSaving = false);
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: VSPSpacing.md),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String value, String label, {bool isRedArrow = false, required double width}) {
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
           Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               if (isRedArrow) const Icon(Icons.arrow_drop_down, color: VSPColors.error, size: 20),
               Text(
                 value, 
                 style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
               ),
             ],
           ),
           Text(
             label,
             textAlign: TextAlign.center,
             style: paramTextStyle(fontSize: 9),
           )
        ],
      ),
    );
  }

  TextStyle paramTextStyle({required double fontSize}) => TextStyle(color: VSPColors.textSecondary, fontSize: fontSize);

  Widget _buildTextField(TextEditingController controller, {String? hint, bool readOnly = false}) {
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
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
    return CircleAvatar(
      radius: 16,
      backgroundColor: VSPColors.surface,
      backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
      child: imageUrl.isEmpty ? const Icon(Icons.person, color: VSPColors.textSecondary, size: 16) : null,
    );
  }

  Widget _buildMemberChip(UserModel user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: VSPColors.white12,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: VSPColors.surface,
              backgroundImage: (user.profileImageUrl?.isNotEmpty ?? false) ? NetworkImage(user.profileImageUrl!) : null,
              child: (user.profileImageUrl?.isEmpty ?? true) ? const Icon(Icons.person, color: VSPColors.textSecondary, size: 12) : null,
            ),
            const SizedBox(width: VSPSpacing.sm),
            Text(user.name ?? 'Player', style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12)),
           const SizedBox(width: 4),
            if (isCaptain)
              GestureDetector(
                onTap: () async {
                  final userToRemove = user;
                  setState(() {
                    _teamMembers.removeWhere((m) => m.uid == userToRemove.uid);
                    // Note: We do not manually mutate _myTeam here because its fields are generated
                    // and we will rely on _fetchMyTeam() below to sync the exact state from Firestore.
                  });
                  
                  if (_myTeam != null) {
                    await DatabaseService().removeMemberFromTeam(
                      _myTeam!.id, 
                      userToRemove.uid, 
                      userToRemove.profileImageUrl ?? ''
                    );
                    _fetchMyTeam(); // Sync state with server
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.close, color: VSPColors.textPrimary, size: 14),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildAchievementSection(Team team) {
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
            const Text(
              'Team Achievements',
              style: TextStyle(
                color: VSPColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                
                letterSpacing: 1.1,
              ),
            ),
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
                    const Icon(Icons.bolt, color: VSPColors.warning, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${team.currentWinningStreak} Win Streak',
                      style: const TextStyle(color: VSPColors.warning, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: VSPSpacing.md),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 20),
            itemBuilder: (context, index) {
              final badge = badges[index];
              final isUnlocked = team.unlockedBadges.contains(badge['id']);
              
              return GestureDetector(
                onTap: () {
                  _showBadgeInfo(badge['name'] as String, badge['desc'] as String, isUnlocked);
                },
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isUnlocked ? VSPColors.accent.withValues(alpha: 0.1) : VSPColors.surfaceAlt.withValues(alpha: 0.5),
                        border: Border.all(
                          color: isUnlocked ? VSPColors.accent : VSPColors.divider,
                          width: 2,
                        ),
                        boxShadow: isUnlocked ? VSPShadow.subtle : [],
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
                        color: isUnlocked ? VSPColors.textPrimary : VSPColors.textSecondary.withValues(alpha: 0.3),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
            Text(
              isUnlocked ? "Status: Unlocked! Keep it up." : "Status: Locked. Complete the requirement to earn this badge.",
              style: TextStyle(
                color: isUnlocked ? VSPColors.accent : VSPColors.error,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          PrimaryButton(
            text: "Got it",
            height: 48,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: const Text("Delete Team", style: TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text(
          "Are you sure? This action cannot be undone and your team and achievements will be lost.",
          style: TextStyle(color: VSPColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: "Cancel",
                  height: 48,
                  color: VSPColors.surfaceAlt,
                  textColor: VSPColors.textPrimary,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: PrimaryButton(
                  text: 'Delete',
                  height: 48,
                  color: VSPColors.error,
                  textColor: VSPColors.background,
                  onPressed: () async {
                    Navigator.pop(context);
                    if (_myTeam != null) {
                      final success = await DatabaseService().deleteTeam(_myTeam!.id);
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Team deleted successfully'), backgroundColor: VSPColors.error),
                        );
                        Navigator.pop(context); // Go back to profile
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
