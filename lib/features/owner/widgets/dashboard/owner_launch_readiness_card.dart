import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/ui/components/vsp_button.dart';

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

  String _getTitle(bool isAr) {
    if (_isRejected) {
      return isAr ? 'مطلوب تحديث المستندات' : 'Documents Need Attention';
    }
    if (_isPending && hasStadium) {
      return isAr ? 'منشأتك جاهزة وبانتظار الاعتماد' : 'Ready — Awaiting Admin Approval';
    }
    return isAr ? 'خطوات إطلاق منشأتك' : 'Your Launch Checklist';
  }

  String _getSubtitle(bool isAr) {
    if (_isRejected) {
      return isAr
          ? 'تم رفض بعض المستندات المرفوعة. يرجى إعادة رفع الوثائق المطلوبة لاعتماد المنشأة.'
          : 'Please update your uploaded documents for approval.';
    }
    if (_isPending && hasStadium) {
      return isAr
          ? 'أحسنت! أكملت خطوات الإعداد المطلوبة. أوراقك قيد الفحص الإداري وستنطلق فور الاعتماد.'
          : 'Great job! Setup complete. Your documents are being audited and will go live upon approval.';
    }
    if (_isPending && !hasStadium) {
      return isAr
          ? 'مستنداتك قيد التدقيق الإداري. استغل هذا الوقت لإضافة ملاعبك وضبط الأسعار لتنطلق فور الاعتماد.'
          : 'Docs under review. Use this time to set up your pitches & prices to be ready at launch.';
    }
    if (!_isPending && hasStadium) {
      return isAr
          ? 'ملاعبك جاهزة ومحفوظة. يرجى رفع مستنداتك الرسمية لاعتماد وتفعيل المنشأة للاعبين.'
          : 'Pitches configured! Please upload official documents to activate your venue.';
    }
    return isAr
        ? 'أكمل الخطوات التالية لبدء استقبال الحجوزات من اللاعبين.'
        : 'Complete these steps to start receiving bookings from players.';
  }

  @override
  Widget build(BuildContext context) {
    final title = _getTitle(isArabic);
    final subtitle = _getSubtitle(isArabic);
    final bool isAllTasksDone = _isPending && hasStadium;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(
          color: isAllTasksDone
              ? VSPColors.accent.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.07),
          width: isAllTasksDone ? 1.2 : 1.0,
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
          // ── العنوان الديناميكي ──
          Row(
            children: [
              Icon(
                isAllTasksDone ? Iconsax.verify_copy : Iconsax.direct_up_copy,
                color: isAllTasksDone ? VSPColors.accent : VSPColors.accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                title,
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
            subtitle,
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
            iconColor: _isRejected ? VSPColors.error : VSPColors.textSecondary,
            title: isArabic ? 'مراجعة المستندات' : 'Document Review',
            subtitle: _isRejected
                ? (isArabic ? 'تم رفض بعض المستندات - يرجى إعادة الرفع' : 'Documents rejected - please re-upload')
                : _isPending
                    ? (isArabic ? 'قيد التدقيق الإداري (خلال 24 ساعة عادةً)' : 'Under Admin Review (usually within 24h)')
                    : (isArabic ? 'لم يتم الرفع بعد' : 'Not Submitted Yet'),
            subtitleColor: _isRejected
                ? VSPColors.error
                : VSPColors.textSecondary,
            isArabic: isArabic,
            trailingWidget: _isRejected
                ? VSPActionChip(
                    label: isArabic ? 'إعادة الرفع' : 'Re-upload',
                    onTap: onResubmitDocs,
                    color: VSPColors.error,
                  )
                : (!_isPending
                    ? VSPActionChip(
                        label: isArabic ? 'رفع الوثائق' : 'Upload Docs',
                        onTap: onResubmitDocs,
                        color: VSPColors.accent,
                      )
                    : null),
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
                ? (isArabic ? 'تم حفظ بيانات الملاعب وتحديد الأسعار بنجاح' : 'Pitches & pricing configured successfully')
                : (isArabic ? 'أضف ملاعبك لتكون جاهزاً فور الاعتماد' : 'Add your pitch to be ready at launch'),
            subtitleColor: hasStadium
                ? VSPColors.accent
                : VSPColors.textSecondary,
            isArabic: isArabic,
            trailingWidget: VSPActionChip(
              label: hasStadium
                  ? (isArabic ? 'تعديل الملعب' : 'Edit Pitch')
                  : (isArabic ? 'إضافة ملعب' : 'Add Pitch'),
              icon: hasStadium ? Iconsax.edit_2_copy : Iconsax.add_circle_copy,
              isOutlined: hasStadium,
              color: hasStadium ? VSPColors.textSecondary : VSPColors.accent,
              onTap: onAddStadium,
            ),
          ),
          const _StepDivider(),

          // ── الخطوة 4: استقبال الحجوزات ──
          _StepRow(
            icon: Iconsax.flash_1_copy,
            iconColor: Colors.white30,
            title: isArabic ? 'استقبال الحجوزات' : 'Go Live — Receive Bookings',
            subtitle: isArabic
                ? 'تُفعّل تلقائياً وتظهر منشأتك للاعبين فور اكتمال الاعتماد'
                : 'Activates automatically and goes live upon admin approval',
            subtitleColor: Colors.white38,
            isArabic: isArabic,
          ),

          // ── تنبيه طمأنة وتوضيح أثناء التدقيق الإداري ──
          if (_isPending) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Iconsax.info_circle_copy,
                    color: VSPColors.accent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'يقوم فريق الإدارة بمراجعة أوراق منشأتك حالياً. ستتلقى إشعاراً فور تفعيل الحساب وبدء استقبال الحجوزات.'
                          : 'Our admin team is reviewing your facility documents. You will be notified the moment your venue goes live.',
                      style: const TextStyle(
                        color: VSPColors.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
