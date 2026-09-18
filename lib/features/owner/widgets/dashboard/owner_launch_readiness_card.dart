import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// بطاقة مراحل إطلاق المنشأة للمالك غير المعتمد بعد.
///
/// تعرض خطوات الإطلاق الأربع بحالة كل منها بوضوح:
///   1. إنشاء الحساب (دائماً مكتمل هنا)
///   2. مراجعة المستندات (pending / rejected)
///   3. إعداد الملاعب (متاح دائماً)
///   4. استقبال الحجوزات (ينشط تلقائياً عند الاعتماد)
///
/// تُعرض هذه البطاقة بدلاً من كروت الإيرادات والحجوزات اليومية
/// طالما أن المالك لم يُعتمد بعد.
class OwnerLaunchReadinessCard extends StatelessWidget {
  final String? verificationStatus;
  final bool hasStadium;
  final bool isArabic;
  final VoidCallback onAddStadium;
  final VoidCallback onResubmitDocs;

  const OwnerLaunchReadinessCard({
    super.key,
    required this.verificationStatus,
    required this.hasStadium,
    required this.isArabic,
    required this.onAddStadium,
    required this.onResubmitDocs,
  });

  bool get _isRejected => verificationStatus == 'rejected';
  bool get _isPending =>
      verificationStatus == 'pending' || verificationStatus == 'under_review';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── العنوان ──
          Row(
            children: [
              const Icon(Iconsax.direct_up_copy, color: VSPColors.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'خطوات إطلاق منشأتك' : 'Your Launch Checklist',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isArabic
                ? 'أكمل الخطوات التالية لبدء استقبال الحجوزات من اللاعبين.'
                : 'Complete these steps to start receiving bookings from players.',
            style: const TextStyle(
              color: VSPColors.textSecondary,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // ── الخطوة 1: إنشاء الحساب (مكتملة دائماً) ──
          _StepRow(
            icon: Iconsax.tick_circle_copy,
            iconColor: VSPColors.accent,
            title: isArabic ? 'إنشاء الحساب' : 'Account Created',
            subtitle: isArabic ? 'مكتمل' : 'Completed',
            subtitleColor: VSPColors.accent,
            isArabic: isArabic,
          ),
          const _StepDivider(),

          // ── الخطوة 2: مراجعة المستندات ──
          _StepRow(
            icon: _isRejected
                ? Iconsax.close_circle_copy
                : Iconsax.timer_1_copy,
            iconColor: _isRejected ? VSPColors.error : const Color(0xFFF59E0B),
            title: isArabic ? 'مراجعة المستندات' : 'Document Review',
            subtitle: _isRejected
                ? (isArabic ? 'مطلوب إعادة الرفع' : 'Re-upload Required')
                : _isPending
                    ? (isArabic ? 'قيد التدقيق الإداري' : 'Under Admin Review')
                    : (isArabic ? 'لم يتم الرفع بعد' : 'Not Submitted Yet'),
            subtitleColor: _isRejected
                ? VSPColors.error
                : const Color(0xFFF59E0B),
            isArabic: isArabic,
            trailingWidget: _isRejected
                ? _ActionChip(
                    label: isArabic ? 'إعادة الرفع' : 'Re-upload',
                    onTap: onResubmitDocs,
                    color: VSPColors.error,
                  )
                : null,
          ),
          const _StepDivider(),

          // ── الخطوة 3: إعداد الملاعب ──
          _StepRow(
            icon: hasStadium
                ? Iconsax.tick_circle_copy
                : Iconsax.element_4_copy,
            iconColor: hasStadium
                ? VSPColors.accent
                : VSPColors.textSecondary,
            title: isArabic ? 'إعداد الملاعب والأسعار' : 'Configure Pitches & Prices',
            subtitle: hasStadium
                ? (isArabic ? 'تمت الإضافة، راجع الأسعار' : 'Added — review pricing')
                : (isArabic ? 'أضف ملعبك الآن لتكون جاهزاً' : 'Add your pitch to be ready at launch'),
            subtitleColor: hasStadium
                ? VSPColors.accent
                : VSPColors.textSecondary,
            isArabic: isArabic,
            trailingWidget: _ActionChip(
              label: hasStadium
                  ? (isArabic ? 'ضبط الأسعار' : 'Set Prices')
                  : (isArabic ? 'إضافة ملعب' : 'Add Pitch'),
              onTap: onAddStadium,
              color: VSPColors.accent,
            ),
          ),
          const _StepDivider(),

          // ── الخطوة 4: استقبال الحجوزات ──
          _StepRow(
            icon: Iconsax.flash_1_copy,
            iconColor: Colors.white30,
            title: isArabic ? 'استقبال الحجوزات' : 'Go Live — Receive Bookings',
            subtitle: isArabic
                ? 'يُفعَّل تلقائياً فور الاعتماد الإداري'
                : 'Activates automatically upon admin approval',
            subtitleColor: Colors.white38,
            isArabic: isArabic,
          ),
        ],
      ),
    );
  }
}

// ── مكونات مساعدة داخلية ───────────────────────────────────

class _StepRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final bool isArabic;
  final Widget? trailingWidget;

  const _StepRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.isArabic,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: VSPColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (trailingWidget != null) ...[
            const SizedBox(width: 8),
            trailingWidget!,
          ],
        ],
      ),
    );
  }
}

class _StepDivider extends StatelessWidget {
  const _StepDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: Colors.white.withValues(alpha: 0.06),
      height: 1,
      thickness: 1,
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionChip({
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(VSPRadius.sm),
          border: Border.all(
            color: color.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
