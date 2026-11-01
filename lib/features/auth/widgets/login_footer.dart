import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../l10n/app_localizations.dart';

class LoginFooter extends StatelessWidget {
  const LoginFooter({super.key});

  void _showRoleSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _RoleSelectionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text(
          l10n.dontHaveAccount,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: VSPColors.textSecondary,
                fontSize: 14,
              ),
        ),
        TextButton(
          onPressed: () => _showRoleSheet(context),
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            l10n.signUp,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: VSPColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
          ),
        ),
      ],
    );
  }
}

class _RoleSelectionSheet extends StatelessWidget {
  const _RoleSelectionSheet();

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Container(
          decoration: const BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(VSPRadius.bottomSheet),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: VSPColors.textMuted,
              borderRadius: BorderRadius.circular(VSPRadius.full),
            ),
          ),
          const SizedBox(height: 28),

          // Title
          Text(
            isArabic ? 'إنشاء حساب جديد' : 'Create a new account',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'اختار نوع حسابك عشان نكمل معاك'
                : 'Choose your account type to continue',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: VSPColors.textSecondary,
                  fontSize: 14,
                ),
          ),
          const SizedBox(height: 28),

          // زر لاعب
          _RoleCard(
            icon: Iconsax.cup_copy,
            title: isArabic ? 'لاعب' : 'Player',
            subtitle: isArabic
                ? 'احجز ملاعب، انضم لمباريات، وتابع إحصائياتك'
                : 'Book pitches, join matches, and track your stats',
            onTap: () {
              Navigator.pop(context);
              context.push('/create-account-player');
            },
          ),
          const SizedBox(height: 12),

          // زر صاحب ملعب
          _RoleCard(
            icon: Iconsax.building_3_copy,
            title: isArabic ? 'صاحب ملعب' : 'Stadium owner',
            subtitle: isArabic
                ? 'سجّل ملعبك وابدأ استقبال الحجوزات'
                : 'Register your stadium and start accepting bookings',
            onTap: () {
              Navigator.pop(context);
              context.push('/create-account-owner');
            },
          ),
          const SizedBox(height: 8),
          ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(VSPRadius.card),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.card),
          border: Border.all(color: VSPColors.borderLight, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(
                  color: VSPColors.borderAccent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: VSPColors.accent,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: VSPColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: VSPColors.textSecondary,
                          fontSize: 13,
                        ),
                  ),
                ],
              ),
            ),
            Transform.flip(
              flipX: Directionality.of(context) == TextDirection.rtl,
              child: const Icon(
                Iconsax.arrow_right_3_copy,
                color: VSPColors.textMuted,
                size: 16,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
