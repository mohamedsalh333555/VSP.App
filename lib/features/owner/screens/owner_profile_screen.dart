import 'package:vsp_application/l10n/app_localizations.dart';
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
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../core/ui/components/vsp_menu_item.dart';

class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          l10n.profileSettings, // Assuming profileSettings is available or using hardcoded 'Profile' if not
          style: Theme.of(context).textTheme.displayLarge,
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
            horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Account Section ──
            VSPSectionTitle(l10n.profileAccountLabel),
            const SizedBox(height: VSPSpacing.md),
            VSPFadeInItem(
              index: 0,
              child: VSPMenuItem(
                icon: Icons.person_outline,
                title: l10n.profileAccountLabel,
                subtitle: l10n.profileAccountSubtitle,
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
                  title: l10n.paymentMethods,
                  subtitle: l10n.paymentMethods, // Can refine if needed
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
            VSPSectionTitle(l10n.profilePreferencesLabel),
            const SizedBox(height: VSPSpacing.md),
            VSPFadeInItem(
              index: 2,
              child: VSPMenuItem(
                icon: Icons.notifications_none_outlined,
                title: l10n.profileNotificationsLabel,
                subtitle: l10n.profileNotificationsSubtitle,
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
                title: l10n.profilePrivacyLabel,
                subtitle: l10n.profilePrivacySubtitle,
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
                title: l10n.profileLanguageLabel,
                subtitle: l10n.profileLanguageSubtitle,
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
            VSPSectionTitle(l10n.profileSupportLabel),
            const SizedBox(height: VSPSpacing.md),
            VSPFadeInItem(
              index: 5,
              child: VSPMenuItem(
                icon: Icons.help_outline,
                title: l10n.profileHelpCenterLabel,
                subtitle: l10n.profileHelpCenterSubtitle,
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
                title: l10n.profileLogoutLabel,
                subtitle: l10n.profileLogoutSubtitle,
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
