import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_section_title.dart';
import '../../../core/models/user_model.dart';
import '../../player/screens/profile_subscreens/notifications_screen.dart';
import '../../player/screens/terms_and_privacy_screen.dart';
import '../../player/screens/faq_and_support_screen.dart';
import '../../player/screens/profile_subscreens/language_screen.dart';
import '../../../core/providers/auth_provider.dart';
import 'owner_account_management_screen.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../core/ui/components/vsp_menu_item.dart';

class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userModel;

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          isArabic ? 'ملفي' : 'Profile',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
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
            // ── بطاقة حالة توثيق المنشأة ──
            if (user != null)
              _buildVerificationBadgeCard(context, user, isArabic),

            // ── Account Section ──
            VSPSectionTitle(l10n.profileAccountLabel),
            const SizedBox(height: VSPSpacing.md),
            VSPFadeInItem(
              index: 0,
              child: VSPMenuItem(
                icon: Iconsax.user_tick_copy,
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

            const SizedBox(height: VSPSpacing.lg),

            // ── Preferences Section ──
            VSPSectionTitle(l10n.profilePreferencesLabel),
            const SizedBox(height: VSPSpacing.md),
            VSPFadeInItem(
              index: 2,
              child: VSPMenuItem(
                icon: Iconsax.notification_copy,
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
                icon: Iconsax.security_safe_copy,
                title: l10n.profilePrivacyLabel,
                subtitle: l10n.profilePrivacySubtitle,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const TermsAndPrivacyScreen()),
                  );
                },
              ),
            ),
            VSPFadeInItem(
              index: 4,
              child: VSPMenuItem(
                icon: Iconsax.global_copy,
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
                icon: Iconsax.info_circle_copy,
                title: l10n.profileHelpCenterLabel,
                subtitle: l10n.profileHelpCenterSubtitle,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const FAQAndSupportScreen()),
                  );
                },
              ),
            ),

            const SizedBox(height: VSPSpacing.lg),

            // ── Logout ──
            VSPFadeInItem(
              index: 6,
              child: VSPMenuItem(
                icon: Iconsax.logout_copy,
                title: l10n.profileLogoutLabel,
                subtitle: l10n.profileLogoutSubtitle,
                isLogout: true,
                onTap: () async {
                  await Provider.of<AuthProvider>(context, listen: false)
                      .signOut();
                },
              ),
            ),

            SizedBox(height: VSPScrollPadding.bottom(context, hasFloatingNavBar: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationBadgeCard(BuildContext context, UserModel user, bool isArabic) {
    final status = user.verificationStatus;
    final isApproved = user.isVerifiedForOperations;
    final isUnderReview = status == 'under_review';
    final isRejected = status == 'rejected';

    final Color badgeColor = isApproved
        ? VSPColors.accent
        : (isRejected ? VSPColors.error : VSPColors.warning);

    final IconData icon = isApproved
        ? Iconsax.verify_copy
        : (isRejected ? Iconsax.close_circle_copy : Iconsax.timer_1_copy);

    final String statusText = isArabic
        ? (isApproved
            ? 'حساب منشأة معتمد رسمياً'
            : (isRejected
                ? 'تم رفض توثيق المنشأة'
                : (isUnderReview ? 'الوثائق قيد المراجعة والتدقيق' : 'بانتظار توثيق المنشأة')))
        : (isApproved
            ? 'Officially Verified Facility'
            : (isRejected
                ? 'Verification Rejected'
                : (isUnderReview ? 'Documents Under Review' : 'Facility Verification Required')));

    return GestureDetector(
      onTap: isApproved ? null : () => context.push('/documentation'),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: VSPSpacing.md),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(VSPRadius.card),
          border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: badgeColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic
                        ? (isApproved
                            ? 'جميع عمليات التشغيل واستقبال الحجوزات مفعلة بالكامل'
                            : 'اضغط هنا لمتابعة حالة وثائق ومستندات المنشأة')
                        : (isApproved
                            ? 'All operations and bookings are fully active'
                            : 'Tap to view or update facility documents'),
                    style: const TextStyle(
                      color: VSPColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (!isApproved)
              const Icon(Icons.arrow_forward_ios, color: VSPColors.textSecondary, size: 14),
          ],
        ),
      ),
    );
  }
}



