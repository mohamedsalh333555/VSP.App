import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';

class TeamLeagueOnboardingCard extends StatelessWidget {
  final VoidCallback onCreateLeague;
  final VoidCallback onJoinLeague;

  const TeamLeagueOnboardingCard({
    super.key,
    required this.onCreateLeague,
    required this.onJoinLeague,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(VSPSpacing.xl),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: VSPColors.accent.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    VSPColors.accent.withValues(alpha: 0.2),
                    VSPColors.accent.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: VSPColors.accent, width: 2),
              ),
              child: const Icon(
                Iconsax.cup_copy,
                color: VSPColors.accent,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: VSPSpacing.md),
          const Text(
            '🏆 ابدأ دوري فريقك',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'اجمع 4 فرق وشوف مين بطل الدوري',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VSPColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: VSPSpacing.lg),

          // League Features Pills
          _buildFeatureRow(
            icon: Iconsax.people_copy,
            title: '4 فرق متنافسة',
            subtitle: 'دوري مصغر حماسي بين 4 فرق فقط',
          ),
          const SizedBox(height: 10),
          _buildFeatureRow(
            icon: Iconsax.calendar_1_copy,
            title: '3 جولات (6 مباريات)',
            subtitle: 'كل فريق يلعب 3 مباريات، مباراة كل أسبوع',
          ),
          const SizedBox(height: 10),
          _buildFeatureRow(
            icon: Iconsax.wallet_copy,
            title: '30 جنيه رسوم لكل فريق',
            subtitle: 'رسوم اشتراك الفريق بالكامل',
            highlight: true,
          ),

          const SizedBox(height: VSPSpacing.xl),

          PrimaryButton(
            text: 'إنشاء دوري لفريقك (30 ج)',
            onPressed: onCreateLeague,
          ),

          const SizedBox(height: 10),

          OutlinedButton.icon(
            onPressed: onJoinLeague,
            icon: const Icon(Iconsax.login_copy, size: 18),
            label: const Text(
              'الانضمام لدوري موجود بكود',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: VSPColors.textPrimary,
              side: const BorderSide(color: VSPColors.borderLight),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VSPRadius.md),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? VSPColors.accent.withValues(alpha: 0.1) : VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: highlight ? VSPColors.accent.withValues(alpha: 0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: highlight ? VSPColors.accent : VSPColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: highlight ? VSPColors.accent : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
