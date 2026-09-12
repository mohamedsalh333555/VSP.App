import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppLocalizations.of(context)!.dontHaveAccount,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: VSPColors.textSecondary,
                fontSize: 14,
              ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => _showRoleSheet(context),
          child: Text(
            AppLocalizations.of(context)!.signUp,
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
    return Container(
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(VSPRadius.bottomSheet),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
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
            'إنشاء حساب جديد',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'اختار نوع حسابك عشان نكمل معاك',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: VSPColors.textSecondary,
                  fontSize: 14,
                ),
          ),
          const SizedBox(height: 28),

          // زر لاعب
          _RoleCard(
            icon: Icons.sports_soccer_rounded,
            title: 'لاعب',
            subtitle: 'احجز ملاعب، انضم لمباريات، وتابع إحصائياتك',
            onTap: () {
              Navigator.pop(context);
              context.push('/create-account-player');
            },
          ),
          const SizedBox(height: 12),

          // زر صاحب ملعب
          _RoleCard(
            icon: Icons.stadium_rounded,
            title: 'صاحب ملعب',
            subtitle: 'سجّل ملعبك وابدأ استقبال الحجوزات',
            onTap: () {
              Navigator.pop(context);
              context.push('/create-account-owner');
            },
          ),
          const SizedBox(height: 8),
        ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
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
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: VSPColors.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
