import 'package:flutter/material.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/core/ui/components/vsp_section_title.dart';
import 'package:vsp_application/core/utils/elo_calculator.dart';
import 'profile_subscreens/my_team_screen.dart';
import 'profile_subscreens/payment_methods_screen.dart';
import 'profile_subscreens/notifications_screen.dart';
import 'profile_subscreens/privacy_policy_screen.dart';
import 'profile_subscreens/language_screen.dart';
import 'profile_subscreens/help_center_screen.dart';
import 'profile_subscreens/edit_profile_screen.dart';
import 'profile_subscreens/favorites_screen.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../admin/screens/admin_dashboard.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/config/app_config.dart';
import '../../auth/screens/welcome_screen.dart';
import '../../../core/ui/components/vsp_menu_item.dart';
import '../../../core/services/stats_service.dart';
import '../../../core/widgets/radar_chart.dart';
import 'dart:ui';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';
import 'package:flutter/services.dart';
import '../../../core/services/database_service.dart';
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userProfileUrl = auth.userModel?.profileImageUrl;

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Profile',
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Player Card - REDESIGNED
            FutureBuilder<Map<String, dynamic>>(
              future: StatsService().getPlayerStats(auth.currentUser!.uid),
              builder: (context, statsSnapshot) {
                return FutureBuilder<Team?>(
                  future: DatabaseService().getUserTeam(auth.currentUser!.uid),
                  builder: (context, teamSnapshot) {
                    final team = teamSnapshot.data;
                    final stats = statsSnapshot.data ?? {};
                    final elo = team?.points ?? 1200;
                    final rank = EloCalculator.getRankTitle(elo);
                    final skillMetrics = StatsService().getSkillMetrics(auth.userModel?.position, elo);

                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(VSPRadius.lg),
                        border: Border.all(color: VSPColors.white12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            VSPColors.textPrimary.withValues(alpha: 0.15),
                            VSPColors.textPrimary.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(VSPRadius.lg),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(VSPSpacing.lg),
                            child: Column(
                              children: [
                                // Header: Rank & Profile
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: VSPColors.accent.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(VSPRadius.xs),
                                            border: Border.all(color: VSPColors.accent.withOpacity(0.5)),
                                          ),
                                          child: Text(
                                            rank.toUpperCase(),
                                            style: const TextStyle(
                                              color: VSPColors.accent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          auth.userModel?.name ?? 'Player',
                                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Position: ${auth.userModel?.position ?? "ST"}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                    GestureDetector(
                                      onLongPress: () {
                                        // 🔐 SECRET GATE: Long press profile image for Admin Dashboard
                                        HapticFeedback.heavyImpact();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('⚡ Admin Mode Activated', style: TextStyle(color: VSPColors.accent)))
                                        );
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
                                      },
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: VSPColors.accent, width: 2),
                                          image: (userProfileUrl != null && userProfileUrl.isNotEmpty) 
                                            ? DecorationImage(
                                                image: CachedNetworkImageProvider(userProfileUrl),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                        ),
                                        child: (userProfileUrl == null || userProfileUrl.isEmpty)
                                            ? const Icon(Icons.person, color: VSPColors.accent, size: 40)
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const Divider(color: VSPColors.divider, height: 40),

                                // Skill Chart & Main Stats
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: VSPRadarChart(
                                        values: skillMetrics,
                                        size: 140,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                            _buildCardStat(context, 'WIN RATE', '${stats['winRate'] ?? "0"}%', VSPColors.accent),
                                            const SizedBox(height: 16),
                                            _buildCardStat(context, 'GOALS', '${stats['totalGoals'] ?? "0"}', VSPColors.textPrimary),
                                            const SizedBox(height: 16),
                                            _buildCardStat(context, 'MATCHES', '${stats['matchesPlayed'] ?? "0"}', VSPColors.textPrimary),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                // Favorite Stadium Footer
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: VSPColors.background.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(VSPRadius.md),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.star, color: VSPColors.warning, size: 14),
                                      const SizedBox(width: 8),
                                      Text(
                                        'FAVORITE STADIUM: ${stats['favoriteStadium'] ?? "None"}',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: VSPSpacing.lg),

            // Achievement Badges Section
            const VSPSectionTitle('Achievements'),
            const SizedBox(height: VSPSpacing.sm),
            SizedBox(
              height: 90,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildBadge(context, 'Night Owl', Icons.nightlight_round, true),
                  _buildBadge(context, 'Top Scorer', Icons.military_tech, true),
                  _buildBadge(context, 'Clean Sheet', Icons.shield, false),
                  _buildBadge(context, 'Marathoner', Icons.directions_run, false),
                  _buildBadge(context, 'Fair Play', Icons.handshake, true),
                ],
              ),
            ),

            const SizedBox(height: VSPSpacing.lg),

            // Account Section - REFINED HEADER
            const VSPSectionTitle('Account'),
            const SizedBox(height: VSPSpacing.sm),
            VSPMenuItem(
              icon: Icons.groups_outlined,
              title: 'My Team',
              subtitle: 'Manage Your Team Information',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamScreen())),
            ),
            VSPMenuItem(
              icon: Icons.favorite_border,
              title: 'Favorite Stadiums',
              subtitle: 'View Your Liked Facilities',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen())),
            ),
            if (AppConfig.enableOnlinePayment) ...[
              VSPMenuItem(
                icon: Icons.payment_outlined,
                title: 'Payment Methods',
                subtitle: 'Manage Your Payment Methods',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsScreen())),
              ),
              const SizedBox(height: VSPSpacing.md),
            ],

            const SizedBox(height: VSPSpacing.lg),

            // Preferences Section - REFINED HEADER
            const VSPSectionTitle('Preferences'),
            const SizedBox(height: VSPSpacing.sm),
            VSPMenuItem(
              icon: Icons.notifications_none_outlined,
              title: 'Notifications',
              subtitle: 'Manage Your Notification Settings',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            ),
            const SizedBox(height: VSPSpacing.md),
            VSPMenuItem(
              icon: Icons.shield_outlined,
              title: 'Privacy',
              subtitle: 'Privacy Policy',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
            ),
            const SizedBox(height: VSPSpacing.md),
            VSPMenuItem(
              icon: Icons.translate,
              title: 'Language',
              subtitle: 'Manage Your Language Preferences',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageScreen())),
            ),
             const SizedBox(height: VSPSpacing.md),
            VSPMenuItem(
              icon: Icons.help_outline,
              title: 'Help Center',
              subtitle: 'Get Help & Support',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterScreen())),
            ),

            const SizedBox(height: VSPSpacing.md),
            VSPMenuItem(
              icon: Icons.feedback_outlined,
              title: 'Feedback',
              subtitle: 'Report an issue or suggest a feature',
              onTap: () => _showFeedbackDialog(context),
            ),
            const SizedBox(height: VSPSpacing.md),

            // Logout Button
            VSPMenuItem(
              icon: Icons.logout,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              isLogout: true,
              onTap: () async {
                await Provider.of<AuthProvider>(context, listen: false).signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (route) => false,
                  );
                }
              },
            ),
            
            // Bottom Padding
            SizedBox(height: MediaQuery.of(context).padding.bottom + 110),
          ],
        ),
      ),
    ),
    );
  }



  Widget _buildCardStat(BuildContext context, String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary, fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBadge(BuildContext context, String name, IconData icon, bool isUnlocked) {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUnlocked ? VSPColors.accentSoft : VSPColors.surfaceAlt,
              border: Border.all(color: isUnlocked ? VSPColors.accent : VSPColors.divider),
            ),
            child: Icon(icon, color: isUnlocked ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.3), size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isUnlocked ? VSPColors.textPrimary : VSPColors.textSecondary.withValues(alpha: 0.3), fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            height: 0.9,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: VSPSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    String feedbackText = '';
    XFile? attachedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: VSPColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
          title: const Text('Send Feedback', style: TextStyle(color: VSPColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                maxLines: 3,
                style: const TextStyle(color: VSPColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Describe the issue...',
                  hintStyle: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.5)),
                  fillColor: VSPColors.background,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(VSPRadius.md), borderSide: BorderSide.none),
                ),
                onChanged: (val) => feedbackText = val,
              ),
              const SizedBox(height: 16),
              if (attachedImage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(attachedImage!.path),
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setDialogState(() => attachedImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: VSPColors.background.withValues(alpha: 0.7), shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: VSPColors.textPrimary, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  final picker = ImagePicker();
                  final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) setDialogState(() => attachedImage = pickedFile);
                },
                icon: const Icon(Icons.add_a_photo, color: VSPColors.accent),
                label: const Text('Attach Screenshot', style: TextStyle(color: VSPColors.accent)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: VSPColors.accent)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: VSPColors.textSecondary)),
            ),
            PrimaryButton(
              text: 'Submit',
              width: 120,
              height: 44,
              onPressed: () async {
                if (feedbackText.isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter some feedback')));
                   return;
                }
                HapticFeedback.mediumImpact();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you for your feedback!')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
