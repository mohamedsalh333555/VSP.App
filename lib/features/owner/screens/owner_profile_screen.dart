import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/ui/components/vsp_menu_item.dart';
import '../../../core/ui/components/vsp_section_title.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/arabic_plural_utils.dart';
import '../../../data/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../player/screens/faq_and_support_screen.dart';
import '../../player/screens/profile_subscreens/language_screen.dart';
import '../../player/screens/profile_subscreens/notifications_screen.dart';
import '../../player/screens/terms_and_privacy_screen.dart';
import 'owner_account_management_screen.dart';
import 'owner_ledger_screen.dart';
import 'subscription_plans_screen.dart';

class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Row(
          children: [
            const Icon(Iconsax.logout_copy, color: VSPColors.error, size: 22),
            const SizedBox(width: 8),
            Text(
              isAr ? 'تسجيل الخروج' : 'Log Out',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          isAr
              ? 'هل أنت متأكد من رغبتك في تسجيل الخروج من حساب المالك؟'
              : 'Are you sure you want to sign out of your owner account?',
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(isAr ? 'تسجيل الخروج' : 'Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await Provider.of<AuthProvider>(context, listen: false).signOut();
    }
  }

  Widget _buildOwnerHeader(BuildContext context, AuthProvider auth, bool isArabic) {
    final user = auth.userModel;
    final name = user?.name ?? (isArabic ? 'مالك المنشأة' : 'Stadium Owner');
    final phone = user?.phone ?? '';
    final isVerified = user?.isIdentityVerified == true || user?.verificationStatus == 'approved';
    final photoUrl = user?.profileImageUrl;

    return Container(
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: VSPColors.accent, width: 2),
            ),
            child: ClipOval(
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildAvatarFallback(name),
                    )
                  : _buildAvatarFallback(name),
            ),
          ),
          const SizedBox(width: 14),

          // Owner Details & Badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: VSPColors.textPrimary,
                        fontSize: 17,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: const TextStyle(
                      color: VSPColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // Status Badges Row
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Verification Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isVerified
                            ? VSPColors.accent.withValues(alpha: 0.12)
                            : VSPColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(VSPRadius.full),
                        border: Border.all(
                          color: isVerified
                              ? VSPColors.accent.withValues(alpha: 0.3)
                              : VSPColors.divider,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVerified ? Iconsax.verify_copy : Iconsax.clock_copy,
                            size: 11,
                            color: isVerified ? VSPColors.accent : VSPColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVerified
                                ? (isArabic ? 'شريك معتمد' : 'Verified Partner')
                                : (isArabic ? 'قيد التدقيق' : 'Pending Verification'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isVerified ? VSPColors.accent : VSPColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Managed Stadiums Count
                    StreamBuilder<List<Stadium>>(
                      stream: auth.currentUser?.uid.isNotEmpty == true
                          ? StadiumRepository().getOwnerStadiums(auth.currentUser!.uid)
                          : Stream.value([]),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.length ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: VSPColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(VSPRadius.full),
                            border: Border.all(color: VSPColors.divider.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Iconsax.building_copy, size: 11, color: VSPColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                ArabicPluralUtils.formatStadiumCount(count, isArabic: isArabic),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: VSPColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    final initial = name.isNotEmpty ? name.trim().characters.first.toUpperCase() : 'M';
    return Container(
      color: VSPColors.surfaceAlt,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: VSPColors.accent,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final auth = Provider.of<AuthProvider>(context);

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
        padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Owner Business Identity Header ──
            _buildOwnerHeader(context, auth, isArabic),
            const SizedBox(height: VSPSpacing.md),

            const SizedBox(height: VSPSpacing.lg),

            // ── 2. Facility & Account Management Section ──
            VSPSectionTitle(isArabic ? 'إدارة المنشأة والحساب' : l10n.profileAccountLabel),
            const SizedBox(height: VSPSpacing.md),
            VSPFadeInItem(
              index: 0,
              child: VSPMenuItem(
                icon: Iconsax.user_edit_copy,
                title: isArabic ? 'بيانات المالك والمنشأة' : l10n.profileAccountLabel,
                subtitle: isArabic
                    ? 'الاسم، رقم الهاتف، والملاعب المسجلة'
                    : l10n.profileAccountSubtitle,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OwnerAccountManagementScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            VSPFadeInItem(
              index: 1,
              child: VSPMenuItem(
                icon: Iconsax.receipt_2_1_copy,
                title: isArabic ? 'سجل السحوبات' : 'Withdrawal History',
                subtitle: isArabic
                    ? 'عرض المبالغ التي تمت تسويتها وسحبها'
                    : 'View completed and requested withdrawals',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OwnerLedgerScreen(payoutOnly: true)),
                  );
                },
              ),
            ),

            const SizedBox(height: VSPSpacing.lg),

            // ── 4. Preferences Section ──
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
                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
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
                    MaterialPageRoute(builder: (context) => const TermsAndPrivacyScreen()),
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
                    MaterialPageRoute(builder: (context) => const LanguageScreen()),
                  );
                },
              ),
            ),

            const SizedBox(height: VSPSpacing.lg),

            // ── 5. Support Section ──
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
                    MaterialPageRoute(builder: (context) => const FAQAndSupportScreen()),
                  );
                },
              ),
            ),

            const SizedBox(height: VSPSpacing.lg),

            // ── 6. Protected Logout ──
            VSPFadeInItem(
              index: 6,
              child: VSPMenuItem(
                icon: Iconsax.logout_copy,
                title: l10n.profileLogoutLabel,
                subtitle: l10n.profileLogoutSubtitle,
                isLogout: true,
                onTap: () => _confirmSignOut(context),
              ),
            ),

            SizedBox(height: VSPScrollPadding.bottom(context, hasFloatingNavBar: true)),
          ],
        ),
      ),
    );
  }
}
