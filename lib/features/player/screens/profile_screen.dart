import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_image.dart';
import 'profile_subscreens/my_team_screen.dart';
import 'profile_subscreens/payment_methods_screen.dart';
import 'profile_subscreens/notifications_screen.dart';
import 'profile_subscreens/privacy_policy_screen.dart';
import 'profile_subscreens/language_screen.dart';
import 'profile_subscreens/help_center_screen.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers/auth_provider.dart';
import '../../auth/screens/welcome_screen.dart';
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userProfileUrl = auth.userModel?.profileImageUrl;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFamily: 'Agency FB',
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header Card - REFINED
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.neonGreen, width: 2.5),
              ),
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
                          border: Border.all(color: AppTheme.neonGreen, width: 2),
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
                      const SizedBox(width: 16),
                      // Stats - REFINED
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Rank your team', '9', hasArrow: true),
                            _buildStatItem('Enrolled teams', '3', hasArrow: false),
                          ],
                        ),
                      ),
                      // Edit Button
                      GestureDetector(
                        onTap: () => _pickAndUploadImage(context, auth),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.darkBackground,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.neonGreen),
                                )
                              : const Icon(
                                  Icons.edit_outlined,
                                  color: AppTheme.neonGreen,
                                  size: 20,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Info Text - REFINED (Aligned with Avatar left edge)
                  Text(
                    'Name / ${auth.userModel?.name ?? "Player"}  |  Position / ${auth.userModel?.position ?? "GK"}',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      letterSpacing: 0.2,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Points Progress - REFINED (Fully rounded bar)
                   Row(
                    children: [
                       const Text(
                        'Point 210/600',
                        style: TextStyle(
                          color: AppTheme.textSecondary, 
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: LinearProgressIndicator(
                              value: 210 / 600,
                              backgroundColor: Colors.grey.withValues(alpha: 0.2),
                              color: AppTheme.neonGreen,
                              minHeight: 14,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                      ),
                    ],
                   )
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Account Section - REFINED HEADER
            const Text(
              'Account',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: 'Agency FB',
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.groups_outlined,
              title: 'My Team',
              subtitle: 'Manage Your Team Information',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamScreen())),
            ),
            const SizedBox(height: 16),
            _buildMenuItem(
              icon: Icons.payment_outlined,
              title: 'Payment Methods',
              subtitle: 'Manage Your Payment Methods',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsScreen())),
            ),

            const SizedBox(height: 24),

            // Preferences Section - REFINED HEADER
            const Text(
              'Preferences',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: 'Agency FB',
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.notifications_none_outlined,
              title: 'Notifications',
              subtitle: 'Manage Your Notification Settings',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            ),
            const SizedBox(height: 16),
            _buildMenuItem(
              icon: Icons.shield_outlined,
              title: 'Privacy',
              subtitle: 'Privacy Policy',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
            ),
            const SizedBox(height: 16),
            _buildMenuItem(
              icon: Icons.translate,
              title: 'Language',
              subtitle: 'Manage Your Language Preferences',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageScreen())),
            ),
             const SizedBox(height: 16),
            _buildMenuItem(
              icon: Icons.help_outline,
              title: 'Help Center',
              subtitle: 'Get Help & Support',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterScreen())),
            ),

            const SizedBox(height: 16),

            // Logout Button
            _buildMenuItem(
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
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(BuildContext context, AuthProvider auth) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      await auth.updateProfilePhoto(image);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated!'), backgroundColor: AppTheme.neonGreen),
        );
      }
    }
  }

  Widget _buildStatItem(String label, String value, {required bool hasArrow}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasArrow)
          const Icon(Icons.arrow_drop_down, color: Colors.red, size: 24),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 36,
            fontWeight: FontWeight.w900,
            fontFamily: 'Agency FB',
            height: 0.9,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w400,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        color: Colors.transparent,
        child: Row(
          children: [
            // Icon Box - REFINED
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isLogout ? const Color(0xFF2A1A1A) : AppTheme.neonGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isLogout ? Colors.red : Colors.black,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isLogout ? Colors.red : AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Agency FB',
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isLogout 
                        ? Colors.red.withValues(alpha: 0.7) 
                        : const Color(0xFF888888),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            // Chevron Right Icon - REFINED (More visible #555555)
            if (!isLogout) 
              const Icon(
                Icons.chevron_right, 
                color: Color(0xFF555555),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
