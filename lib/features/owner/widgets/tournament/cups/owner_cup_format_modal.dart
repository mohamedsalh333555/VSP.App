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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF3F3F46), width: 2)),
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
              badgeText: isArabic ? 'الأسرع حاسميًا ' : 'Fastest ',
              color: const Color(0xFFFFD700),
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
              badgeText: isArabic ? 'الأكثر شعبية ' : 'Most Popular ',
              color: const Color(0xFFA78BFA),
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
              color: VSPColors.accent,
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
  required Color color,
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
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFA1A1AA),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isArabic ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_1_copy,
            color: const Color(0xFFA1A1AA),
            size: 16,
          ),
        ],
      ),
    ),
  );
}
