import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_section_title.dart';
import '../../player/screens/profile_subscreens/notifications_screen.dart';
import '../../player/screens/profile_subscreens/privacy_policy_screen.dart';
import '../../player/screens/profile_subscreens/language_screen.dart';
import '../../player/screens/profile_subscreens/help_center_screen.dart';
import '../../player/screens/profile_subscreens/payment_methods_screen.dart';
import '../../auth/screens/welcome_screen.dart';
import '../../../core/providers/auth_provider.dart';
import 'owner_account_management_screen.dart';
import '../../../core/config/app_config.dart';
// Subscription screen removed — no longer accessible from profile
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../core/ui/components/vsp_menu_item.dart';

class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          'Profile',
          style: Theme.of(context).textTheme.displayLarge,
        ),
      ),
      body: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
            horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Account Section ──
            const VSPSectionTitle('Account'),
            const SizedBox(height: VSPSpacing.md),
            VSPFadeInItem(
              index: 0,
              child: VSPMenuItem(
                icon: Icons.person_outline,
                title: 'Account',
                subtitle: 'Manage Your Account Information',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const OwnerAccountManagementScreen()),
                  );
                },
              ),
            ),
            if (AppConfig.enableOnlinePayment)
              VSPFadeInItem(
                index: 1,
                child: VSPMenuItem(
                  icon: Icons.payment_outlined,
                  title: 'Payment Methods',
                  subtitle: 'Manage Your Payment Methods',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PaymentMethodsScreen()),
                    );
                  },
                ),
              ),

            const SizedBox(height: VSPSpacing.lg),

            // ── Preferences Section ──
            const VSPSectionTitle('Preferences'),
            const SizedBox(height: VSPSpacing.md),
            VSPFadeInItem(
              index: 2,
              child: VSPMenuItem(
                icon: Icons.notifications_none_outlined,
                title: 'Notifications',
                subtitle: 'Manage Your Notification Settings',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NotificationsScreen()),
                  );
                },
              ),
            ),
            VSPFadeInItem(
              index: 3,
              child: VSPMenuItem(
                icon: Icons.shield_outlined,
                title: 'Privacy',
                subtitle: 'Privacy Policy',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen()),
                  );
                },
              ),
            ),
            VSPFadeInItem(
              index: 4,
              child: VSPMenuItem(
                icon: Icons.language_outlined,
                title: 'Language',
                subtitle: 'Manage Your Language Preferences',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LanguageScreen()),
                  );
                },
              ),
            ),

            const SizedBox(height: VSPSpacing.lg),

            // ── Support Section ──
            const VSPSectionTitle('Support'),
            const SizedBox(height: VSPSpacing.md),
            VSPFadeInItem(
              index: 5,
              child: VSPMenuItem(
                icon: Icons.help_outline,
                title: 'Help Center',
                subtitle: 'Chat With Support',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const HelpCenterScreen()),
                  );
                },
              ),
            ),

            const SizedBox(height: VSPSpacing.lg),

            // ── Logout ──
            VSPFadeInItem(
              index: 6,
              child: VSPMenuItem(
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                isLogout: true,
                onTap: () async {
                  await Provider.of<AuthProvider>(context, listen: false)
                      .signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const WelcomeScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 110),
          ],
        ),
      ),
    );
  }
}
