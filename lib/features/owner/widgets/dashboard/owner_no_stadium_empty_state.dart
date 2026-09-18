import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../screens/add_stadium_wizard.dart';

/// كارت إرشادي وترحيبي فخم يظهر للمالك عندما لا يمتلك أي ملاعب بعد
class OwnerNoStadiumEmptyState extends StatelessWidget {
  final bool isArabic;

  const OwnerNoStadiumEmptyState({
    super.key,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(
          color: VSPColors.accent.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── أيقونة الملعب المتوهجة ──
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  VSPColors.accent.withValues(alpha: 0.25),
                  VSPColors.accent.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: VSPColors.accent.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Icon(
                Iconsax.buildings_2_copy,
                color: VSPColors.accent,
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ── عنوان الكارت ──
          Text(
            isArabic ? 'لم تقم بإضافة أي ملعب بعد' : 'No Pitches Added Yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VSPColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          // ── وصف الكارت الإرشادي ──
          Text(
            isArabic
                ? 'لوحة التحكم والمؤشرات المالية وجداول الحجوزات ستعمل تلقائياً فور تسجيل ملعبك الأول وضبط أوقات العمل والأسعار.'
                : 'Your financial dashboard and booking timelines will activate as soon as you register your first pitch and configure operating hours and rates.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VSPColors.textSecondary.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),

          // ── مسار الخطوات الثلاث السريع (Onboarding Roadmap) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                _buildStepItem(
                  icon: Iconsax.tick_circle_copy,
                  iconColor: VSPColors.accent,
                  title: isArabic ? 'تسجيل حساب المالك والمنشأة' : 'Owner Profile Created',
                  isCompleted: true,
                ),
                const Divider(color: Colors.white10, height: 16),
                _buildStepItem(
                  icon: Iconsax.timer_1_copy,
                  iconColor: const Color(0xFF38BDF8),
                  title: isArabic ? 'تدقيق ومراجعة المستندات الرسمية' : 'Documents Under Audit',
                  isPending: true,
                ),
                const Divider(color: Colors.white10, height: 16),
                _buildStepItem(
                  icon: Iconsax.add_circle_copy,
                  iconColor: VSPColors.accent,
                  title: isArabic ? 'إضافة أول ملعب وتحديد الأسعار' : 'Add First Pitch & Pricing',
                  isNextAction: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── زر الأكشن الكبير لإضافة الملعب الأول ──
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddStadiumWizard()),
                );
              },
              icon: const Icon(Iconsax.add_square_copy, size: 20, color: Colors.black),
              label: Text(
                isArabic ? 'إضافة ملعبي الأول الآن' : 'Add My First Pitch Now',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.accent,
                elevation: 4,
                shadowColor: VSPColors.accent.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VSPRadius.xl),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    bool isCompleted = false,
    bool isPending = false,
    bool isNextAction = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: isNextAction
                  ? VSPColors.textPrimary
                  : (isCompleted ? Colors.white70 : Colors.white60),
              fontSize: 12.5,
              fontWeight: isNextAction ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
        if (isCompleted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(VSPRadius.full),
            ),
            child: Text(
              isArabic ? 'مكتمل' : 'Done',
              style: const TextStyle(color: VSPColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          )
        else if (isPending)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(VSPRadius.full),
            ),
            child: Text(
              isArabic ? 'جاري الفحص' : 'In Review',
              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold),
            ),
          )
        else if (isNextAction)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(VSPRadius.full),
            ),
            child: Text(
              isArabic ? 'خطوتك القادمة' : 'Next Step',
              style: const TextStyle(color: VSPColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
