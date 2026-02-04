import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../player/screens/profile_subscreens/notifications_screen.dart';
import '../../player/screens/profile_subscreens/privacy_policy_screen.dart';
import '../../player/screens/profile_subscreens/language_screen.dart';
import '../../player/screens/profile_subscreens/help_center_screen.dart';
import '../../player/screens/profile_subscreens/payment_methods_screen.dart';
import '../../auth/screens/welcome_screen.dart';
import '../../../core/providers/auth_provider.dart';
import 'owner_account_management_screen.dart';
import 'owner_subscription_screen.dart';

class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Pure Dark
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        automaticallyImplyLeading: false, // No back arrow
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Agency FB', // Condensed Bold
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Account Section ---
            _buildSectionTitle('Account'),
            const SizedBox(height: 16),
             _buildProfileTile(
              context,
              icon: Icons.person_outline,
              title: 'Account',
              subtitle: 'Manage Your Account Information',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const OwnerAccountManagementScreen()));
              },
            ),


            _buildProfileTile(
              context,
              icon: Icons.workspace_premium_outlined, // Crown/Premium icon
              title: 'Subscription',
              subtitle: 'Manage Your Subscription',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const OwnerSubscriptionScreen()));
              },
            ),
            _buildProfileTile(
              context,
              icon: Icons.payment_outlined,
              title: 'Payment Methods',
              subtitle: 'Manage Your Payment Methods',
              onTap: () {
                 Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentMethodsScreen()));
              },
            ),

            const SizedBox(height: 24),

            // --- Preferences Section ---
            _buildSectionTitle('Preferences'),
            const SizedBox(height: 16),
            _buildProfileTile(
              context,
              icon: Icons.notifications_none_outlined,
              title: 'Notifications',
              subtitle: 'Manage Your Notification Settings',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
              },
            ),
            _buildProfileTile(
              context,
              icon: Icons.details_outlined, // Use privacy/shield icon if available, otherwise details
              title: 'Privacy',
              subtitle: 'Privacy Policy',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()));
              },
            ),
            _buildProfileTile(
              context,
              icon: Icons.language_outlined, // Language/Globe icon
              title: 'Language',
              subtitle: 'Manage Your Language Preferences',
              onTap: () {
                 Navigator.push(context, MaterialPageRoute(builder: (context) => const LanguageScreen()));
              },
            ),

             const SizedBox(height: 24),

            // --- Support Section ---
            _buildSectionTitle('Support'),
            const SizedBox(height: 16),
            _buildProfileTile(
              context,
              icon: Icons.help_outline,
              title: 'Help Center',
              subtitle: 'Chat With Support',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpCenterScreen()));
              },
            ),

            const SizedBox(height: 24),
            
             // --- Logout ---
            _buildProfileTile(
              context,
              icon: Icons.logout,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              isLogout: true,
              onTap: () {
                // Clear session and navigate to Welcome Screen
                Provider.of<AuthProvider>(context, listen: false).reset();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              },
            ),
            
            const SizedBox(height: 100), // Bottom padding for Nav Bar
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'Agency FB',
      ),
    );
  }

  Widget _buildProfileTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool isLogout = false}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // Ensure entire row is clickable
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            // Icon Square
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isLogout ? Colors.red.withOpacity(0.1) : AppTheme.neonGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isLogout ? Colors.red : Colors.black,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Texts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isLogout ? Colors.red : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isLogout ? Colors.red.withOpacity(0.7) : Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLogout) Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16),
          ],
        ),
      ),
    );
  }
}
