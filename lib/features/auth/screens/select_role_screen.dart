import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

class SelectRoleScreen extends StatelessWidget {
  const SelectRoleScreen({super.key});

  void _selectRole(BuildContext context, String role) {
    final authProvider = context.read<AuthProvider>();
    authProvider.setUserType(role);
    // الـ Router هيشوف userType اتحدد ويكمل تلقائياً
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // أيقونة VSP
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: VSPColors.accentSoft,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.borderAccent, width: 1),
                ),
                child: const Icon(
                  Iconsax.cup_copy,
                  color: VSPColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(height: 32),

              // العنوان
              Text(
                'أنت هنا عشان إيه؟',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: VSPColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'اختار نوع حسابك عشان نكمّل معاك',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: VSPColors.textSecondary,
                      fontSize: 15,
                    ),
              ),
              const SizedBox(height: 48),

              // بطاقة لاعب
              _RoleCard(
                icon: Iconsax.cup_copy,
                title: 'لاعب',
                subtitle: 'احجز ملاعب، انضم لمباريات، وتابع إحصائياتك',
                onTap: () => _selectRole(context, 'player'),
              ),
              const SizedBox(height: 16),

              // بطاقة صاحب ملعب
              _RoleCard(
                icon: Iconsax.building_3_copy,
                title: 'صاحب ملعب',
                subtitle: 'سجّل ملعبك وابدأ استقبال الحجوزات',
                onTap: () => _selectRole(context, 'owner'),
              ),

              const Spacer(),

              // رابط تسجيل دخول لو عنده حساب تاني
              Center(
                child: GestureDetector(
                  onTap: () {
                    context.read<AuthProvider>().signOut();
                    context.go('/login');
                  },
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: VSPColors.textSecondary,
                            fontSize: 14,
                          ),
                      children: const [
                        TextSpan(text: 'عندك حساب تاني؟ '),
                        TextSpan(
                          text: 'سجّل دخولك',
                          style: TextStyle(
                            color: VSPColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.card),
          border: Border.all(color: VSPColors.borderLight, width: 1),
        ),
        child: Row(
          children: [
            // أيقونة
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: VSPColors.accentSoft,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.borderAccent, width: 1),
              ),
              child: Icon(icon, color: VSPColors.accent, size: 22),
            ),
            const SizedBox(width: 16),

            // نص
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
                  const SizedBox(height: 4),
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

            // سهم
            const Icon(
              Iconsax.arrow_right_3_copy,
              color: VSPColors.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
