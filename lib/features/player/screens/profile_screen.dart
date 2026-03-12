import 'package:flutter/material.dart';
import 'profile_subscreens/my_team_screen.dart';
import 'profile_subscreens/payment_methods_screen.dart';
import 'profile_subscreens/notifications_screen.dart';
import 'profile_subscreens/privacy_policy_screen.dart';
import 'profile_subscreens/language_screen.dart';
import 'profile_subscreens/help_center_screen.dart';
import 'profile_subscreens/edit_profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers/auth_provider.dart';
import '../../auth/screens/welcome_screen.dart';
import '../../../core/services/database_service.dart';
import '../../../data/models.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_section_title.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/ui/components/vsp_menu_item.dart';
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header Card - REFINED
            VSPCard(
              padding: const EdgeInsets.all(VSPSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar with Green Border
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: VSPColors.accent, width: 2),
                        ),
                        child: CircleAvatar(
                          backgroundColor: Colors.transparent,
                          backgroundImage: (userProfileUrl != null && userProfileUrl.isNotEmpty) 
                              ? CachedNetworkImageProvider(userProfileUrl) 
                              : null,
                          child: (userProfileUrl == null || userProfileUrl.isEmpty)
                              ? const Icon(Icons.person, size: 40, color: Colors.white54)
                              : null,
                        ),
                      ),
                      const SizedBox(width: VSPSpacing.md),
                      // Stats - REFINED
                      Expanded(
                        child: FutureBuilder<Team?>(
                          future: DatabaseService().getUserTeam(auth.currentUser!.uid),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: VSPColors.accent,
                                  ),
                                ),
                              );
                            }
                            final team = snapshot.data;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(context, 'Wins', team?.wins.toString() ?? '0'),
                                _buildStatItem(context, 'Matches', team?.matchesPlayed.toString() ?? '0'),
                              ],
                            );
                          },
                        ),
                      ),
                      // Edit Button
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(VSPSpacing.sm),
                          decoration: BoxDecoration(
                            color: VSPColors.background,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            color: VSPColors.accent,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  // Info Text - REFINED (Aligned with Avatar left edge)
                  Text(
                    'Name / ${auth.userModel?.name ?? "Player"}  |  Position / ${auth.userModel?.position ?? "GK"}',
                    style: Theme.of(context).textTheme.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
            const SizedBox(height: VSPSpacing.md),
            VSPMenuItem(
              icon: Icons.payment_outlined,
              title: 'Payment Methods',
              subtitle: 'Manage Your Payment Methods',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsScreen())),
            ),

            const SizedBox(height: VSPSpacing.lg),

            // Preferences Section - REFINED HEADER
            const VSPSectionTitle('Preferences'),
            const SizedBox(height: 12),
            VSPMenuItem(
              icon: Icons.notifications_none_outlined,
              title: 'Notifications',
              subtitle: 'Manage Your Notification Settings',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            ),
            const SizedBox(height: 16),
            VSPMenuItem(
              icon: Icons.shield_outlined,
              title: 'Privacy',
              subtitle: 'Privacy Policy',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
            ),
            const SizedBox(height: 16),
            VSPMenuItem(
              icon: Icons.translate,
              title: 'Language',
              subtitle: 'Manage Your Language Preferences',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageScreen())),
            ),
             const SizedBox(height: 16),
            VSPMenuItem(
              icon: Icons.help_outline,
              title: 'Help Center',
              subtitle: 'Get Help & Support',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterScreen())),
            ),

            const SizedBox(height: 16),

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


}
