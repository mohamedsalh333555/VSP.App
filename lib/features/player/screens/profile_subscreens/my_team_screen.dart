import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../../data/models.dart';
import '../../widgets/add_player_sheet.dart';

class MyTeamScreen extends StatefulWidget {
  const MyTeamScreen({super.key});

  @override
  State<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen> {
  final TextEditingController _teamNameController = TextEditingController(text: 'El Mokatm');
  final TextEditingController _sportsTypeController = TextEditingController(text: 'Football');

  final List<UserModel> _teamMembers = [];
  Team? _myTeam;
  bool _isLoading = true;
  String? _newLogoUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchMyTeam();
  }

  Future<void> _fetchMyTeam() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.userModel?.phone != null) {
      final team = await DatabaseService().getTeamByCaptainPhone(auth.userModel!.phone!);
      if (mounted) {
        setState(() {
          _myTeam = team;
          if (team != null) {
            _teamNameController.text = team.name;
          }
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
        onPlayerAdded: (user) async {
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
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Team',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatCard(_myTeam?.points.toString() ?? '0', 'Points', width: 80),
                  _buildStatCard(((_myTeam?.currentPlayers ?? 0) + _teamMembers.length + (_myTeam == null ? 1 : 0)).toString(), 'Members', width: 80),
                  _buildStatCard(_myTeam?.matchesPlayed.toString() ?? '0', 'Matches', width: 85),
                  _buildStatCard(_myTeam?.wins.toString() ?? '0', 'Wins', width: 85),
                ],
              ),
            
            const SizedBox(height: 24),

            // Team Name
            const Text(
              'Team Name',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _buildTextField(_teamNameController),

            const SizedBox(height: 16),

            // Sports Type
            const Text(
              'Sports Type',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _buildTextField(_sportsTypeController),

            const SizedBox(height: 24),

            // Team Logo & Upload
            Row(
              children: [
                ShimmerImage(
                  imageUrl: _newLogoUrl ?? _myTeam?.captainImageUrl ?? 'https://images.unsplash.com/photo-1543351611-58f69d7c1781?w=150&h=150&fit=crop&q=80',
                  width: 50,
                  height: 50,
                  borderRadius: 25,
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 70,
                    );
                    if (image != null) {
                      setState(() => _isSaving = true);
                      try {
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        final uid = auth.userModel?.uid ?? 'unknown';
                        final url = await CloudinaryService().uploadImage(
                          image,
                          folder: 'teams/$uid/logo',
                        );
                        if (url != null) {
                          setState(() => _newLogoUrl = url);
                        }
                      } finally {
                        setState(() => _isSaving = false);
                      }
                    }
                  },
                  icon: const Icon(Icons.cloud_upload_outlined, color: Colors.black),
                  label: const Text('Upload Photo', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Members Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Team Members (${(_myTeam?.currentPlayers ?? 0) + _teamMembers.length + (_myTeam == null ? 1 : 0)}/12)',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                TextButton.icon(
                  onPressed: _showAddPlayerSheet,
                  icon: const Icon(Icons.add_circle_outline, size: 16, color: AppTheme.neonGreen),
                  label: const Text('Add Member', style: TextStyle(color: AppTheme.neonGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: (_myTeam == null && _teamMembers.isEmpty) 
                  ? Center(child: Text('Add your team members', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Show members from Firestore
                        ...(_myTeam?.playerImages ?? []).map((imgUrl) => _buildMemberAvatar(imgUrl)),
                        // Show locally added members
                        ..._teamMembers.map((member) => _buildMemberChip(member)).toList(),
                      ],
                    ),
            ),

            const SizedBox(height: 32),

            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
            else if (_myTeam != null)
              _buildAchievementSection(_myTeam!)
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "Register your team to start unlocking achievements!",
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              ),

            const SizedBox(height: 40),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Delete Team', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () async {
                      if (_myTeam == null) return;
                      setState(() => _isSaving = true);
                      
                      try {
                        List<String> currentUids = List<String>.from(_myTeam!.memberUids);
                        List<String> currentImages = List<String>.from(_myTeam!.playerImages);
                        
                        for (var member in _teamMembers) {
                          if (!currentUids.contains(member.uid)) {
                            currentUids.add(member.uid);
                            if (member.profileImageUrl != null) currentImages.add(member.profileImageUrl!);
                          }
                        }

                        final success = await DatabaseService().updateTeam(_myTeam!.id, {
                          'name': _teamNameController.text,
                          'captainImageUrl': _newLogoUrl ?? _myTeam!.captainImageUrl,
                          'memberUids': currentUids,
                          'playerImages': currentImages,
                          'playersCount': currentUids.length,
                        });

                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Team updated!'), backgroundColor: AppTheme.neonGreen),
                          );
                          Navigator.pop(context);
                        }
                      } finally {
                        if (mounted) setState(() => _isSaving = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neonGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Text('Save Changes', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neonGreen.withOpacity(0.3)),
        color: AppTheme.cardBackground.withOpacity(0.5),
      ),
      child: Column(
        children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               if (isRedArrow) const Icon(Icons.arrow_drop_down, color: Colors.red, size: 20),
               Text(
                 value, 
                 style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w300, fontFamily: 'AgencyFB'),
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

  TextStyle paramTextStyle({required double fontSize}) => TextStyle(color: AppTheme.textSecondary, fontSize: fontSize);

  Widget _buildTextField(TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(String imageUrl) {
    return ShimmerImage(
      imageUrl: imageUrl,
      width: 32,
      height: 32,
      borderRadius: 16,
    );
  }

  Widget _buildMemberChip(UserModel user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
           ShimmerImage(
             imageUrl: user.profileImageUrl ?? '',
             width: 24,
             height: 24,
             borderRadius: 12,
           ),
           const SizedBox(width: 8),
           Text(user.name ?? 'Player', style: const TextStyle(color: Colors.white, fontSize: 12)),
           const SizedBox(width: 4),
           GestureDetector(
             onTap: () => setState(() => _teamMembers.remove(user)),
             child: const Padding(
               padding: EdgeInsets.all(4.0),
               child: Icon(Icons.close, color: Colors.white, size: 14),
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
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Agency FB',
                letterSpacing: 1.1,
              ),
            ),
            if (team.currentWinningStreak > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.orange, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${team.currentWinningStreak} Win Streak',
                      style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
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
                        color: isUnlocked ? AppTheme.neonGreen.withOpacity(0.1) : const Color(0xFF2C2C2E).withOpacity(0.5),
                        border: Border.all(
                          color: isUnlocked ? AppTheme.neonGreen : Colors.white10,
                          width: 2,
                        ),
                        boxShadow: isUnlocked ? [
                          BoxShadow(color: AppTheme.neonGreen.withOpacity(0.2), blurRadius: 12, spreadRadius: 2),
                        ] : [],
                      ),
                      child: Icon(
                        badge['icon'] as IconData,
                        color: isUnlocked ? AppTheme.neonGreen : Colors.white24,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      badge['name'] as String,
                      style: TextStyle(
                        color: isUnlocked ? AppTheme.textPrimary : Colors.white24,
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
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(name, style: TextStyle(color: isUnlocked ? AppTheme.neonGreen : Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(desc, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            Text(
              isUnlocked ? "Status: Unlocked! Keep it up." : "Status: Locked. Complete the requirement to earn this badge.",
              style: TextStyle(
                color: isUnlocked ? AppTheme.neonGreen : Colors.redAccent,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it", style: TextStyle(color: AppTheme.neonGreen)),
          ),
        ],
      ),
    );
  }
}
