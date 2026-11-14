import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/tokens/vsp_design_tokens.dart';
import '../../../core/ui/vsp_ui.dart';

class SelectRoleScreen extends StatelessWidget {
  const SelectRoleScreen({super.key});

  void _selectRole(BuildContext context, String role) {
    context.read<AuthProvider>().setUserType(role);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return VSPScaffold(
      backgroundColor: VSPDSSemanticColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: VSPDSSpacing.lg,
            vertical: VSPDSSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: VSPDSSpacing.xl),
              Container(
                width: VSPDSizes.stateIconBox,
                height: VSPDSizes.stateIconBox,
                decoration: BoxDecoration(
                  color: VSPDSSemanticColors.iconBadge,
                  borderRadius: BorderRadius.circular(VSPDSRadius.md),
                  border: const Border.fromBorderSide(VSPDSBorders.subtle),
                ),
                child: const Icon(
                  Iconsax.cup_copy,
                  color: VSPDSSemanticColors.accent,
                  size: VSPDSizes.iconXl,
                ),
              ),
              const SizedBox(height: VSPDSSpacing.xl),
              Text(
                isArabic ? 'أنت هنا عشان إيه؟' : 'What brings you to VSP?',
                style: VSPDSTypography.displayMedium,
              ),
              const SizedBox(height: VSPDSSpacing.xs),
              Text(
                isArabic
                    ? 'اختار نوع حسابك عشان نكمّل معاك'
                    : 'Choose the account type that fits how you use VSP.',
                style: VSPDSTypography.bodyLarge,
              ),
              const SizedBox(height: VSPDSSpacing.xl),
              _RoleCard(
                icon: Iconsax.cup_copy,
                title: isArabic ? 'لاعب' : 'Player',
                subtitle: isArabic
                    ? 'احجز ملاعب، انضم لمباريات، وتابع إحصائياتك'
                    : 'Book pitches, join matches, and follow your stats.',
                isArabic: isArabic,
                onTap: () => _selectRole(context, 'player'),
              ),
              const SizedBox(height: VSPDSSpacing.md),
              _RoleCard(
                icon: Iconsax.building_3_copy,
                title: isArabic ? 'صاحب ملعب' : 'Stadium owner',
                subtitle: isArabic
                    ? 'سجّل ملعبك وابدأ استقبال الحجوزات'
                    : 'List your venue and start receiving bookings.',
                isArabic: isArabic,
                onTap: () => _selectRole(context, 'owner'),
              ),
              const SizedBox(height: VSPDSSpacing.xl),
              Center(
                child: Semantics(
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(VSPDSRadius.sm),
                    onTap: () {
                      context.read<AuthProvider>().signOut();
                      context.go('/login');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(VSPDSSpacing.xs),
                      child: RichText(
                        textAlign: TextAlign.center,
                        textDirection: Directionality.of(context),
                        text: TextSpan(
                          style: VSPDSTypography.bodyMedium,
                          children: [
                            TextSpan(
                              text: isArabic ? 'عندك حساب تاني؟ ' : 'Already have an account? ',
                            ),
                            TextSpan(
                              text: isArabic ? 'سجّل دخولك' : 'Log in',
                              style: VSPDSTypography.actionLabel,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
  final bool isArabic;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isArabic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: VSPDSSemanticColors.surface,
        borderRadius: BorderRadius.circular(VSPDSRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VSPDSRadius.card),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: VSPDSAccessibility.minimumTapTarget,
            ),
            width: double.infinity,
            padding: const EdgeInsets.all(VSPDSSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VSPDSRadius.card),
              border: const Border.fromBorderSide(VSPDSBorders.subtle),
            ),
            child: Row(
              textDirection: Directionality.of(context),
              children: [
                Container(
                  width: VSPDSizes.avatarMd,
                  height: VSPDSizes.avatarMd,
                  decoration: BoxDecoration(
                    color: VSPDSSemanticColors.iconBadge,
                    borderRadius: BorderRadius.circular(VSPDSRadius.md),
                  ),
                  child: Icon(
                    icon,
                    color: VSPDSSemanticColors.accent,
                    size: VSPDSizes.iconLg,
                  ),
                ),
                const SizedBox(width: VSPDSSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: VSPDSTypography.titleMedium),
                      const SizedBox(height: VSPDSSpacing.xxs),
                      Text(subtitle, style: VSPDSTypography.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(width: VSPDSSpacing.xs),
                Icon(
                  isArabic ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_3_copy,
                  color: VSPDSSemanticColors.textSecondary,
                  size: VSPDSizes.iconSm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
