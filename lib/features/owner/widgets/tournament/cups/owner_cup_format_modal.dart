import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../screens/create_tournament_wizard.dart';

void showOwnerCupFormatModal(BuildContext context) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.sheet)),
          border: Border(top: BorderSide(color: VSPColors.borderLight, width: 2)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: VSPColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isArabic ? 'اختر نظام البطولة' : 'Choose Tournament Format',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isArabic
                  ? 'اختر النظام التنافسي الأنسب لملعبك وعملائك'
                  : 'Select the best competitive style for your pitch',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            _buildTypeOption(
              ctx,
              icon: Iconsax.cup_copy,
              title: isArabic ? 'خروج المغلوب (كأس)' : 'Knockout (Cup)',
              subtitle: isArabic
                  ? 'مناسب للمنافسات السريعة (الخاسر يخرج فوراً)'
                  : 'Single elimination — Fast & highly competitive',
              badgeText: isArabic ? 'الأسرع حاسمًا' : 'Fastest',
              isArabic: isArabic,
              onTap: () {
                Navigator.pop(ctx);
                CreateTournamentWizard.open(context, preselectedType: 'Cup');
              },
            ),
            const SizedBox(height: 12),
            _buildTypeOption(
              ctx,
              icon: Iconsax.security_safe_copy,
              title: isArabic ? 'مجموعات + تصفيات' : 'Groups & Knockout',
              subtitle: isArabic
                  ? 'مناسب لبطولات رمضان والشركات (مجموعات ثم أدوار إقصائية)'
                  : 'Group stage followed by knockout bracket',
              badgeText: isArabic ? 'الأكثر شعبية' : 'Most Popular',
              isArabic: isArabic,
              onTap: () {
                Navigator.pop(ctx);
                CreateTournamentWizard.open(context, preselectedType: 'GroupsAndKnockout');
              },
            ),
            const SizedBox(height: 12),
            _buildTypeOption(
              ctx,
              icon: Iconsax.award_copy,
              title: isArabic ? 'دوري نقاط كامل' : 'Full League',
              subtitle: isArabic
                  ? 'مناسب للمواسم والبطولات الطويلة (كل الفرق تلعب والترتيب بالنقاط)'
                  : 'Round-robin season — ranked by points',
              isArabic: isArabic,
              onTap: () {
                Navigator.pop(ctx);
                CreateTournamentWizard.open(context, preselectedType: 'League');
              },
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildTypeOption(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required bool isArabic,
  required VoidCallback onTap,
  String? badgeText,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VSPColors.divider, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: VSPColors.borderLight, width: 0.5),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: VSPColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isArabic ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_1_copy,
            color: VSPColors.textMuted,
            size: 16,
          ),
        ],
      ),
    ),
  );
}
