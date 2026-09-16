import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// كارت التوثيق التفاعلي بحالاته الثلاث (معتمد رسمي / قيد المراجعة / غير موثق أو مرفوض)
class OwnerVerificationBanner extends StatelessWidget {
  final UserModel userModel;
  final bool isArabic;

  const OwnerVerificationBanner({
    super.key,
    required this.userModel,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final bool isApproved = userModel.isIdentityVerified == true || userModel.verificationStatus == 'approved';
    final bool isPending = !isApproved && (userModel.verificationStatus == 'pending' || userModel.verificationStatus == 'under_review');
    final bool isRejected = !isApproved && userModel.verificationStatus == 'rejected';

    // 1. منشأة معتمدة وموثقة رسمياً (تظهر كبادج فخر أنيق وموثوق في الهيدر مباشرة بجانب الاسم)
    if (isApproved) {
      return const SizedBox.shrink();
    }

    // 2. المستندات قيد المراجعة من الإدارة
    if (isPending) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0284C7).withValues(alpha: 0.16),
              const Color(0xFF0369A1).withValues(alpha: 0.08),
            ],
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
          ),
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
            width: 0.9,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.timer_1_copy,
                color: Color(0xFF38BDF8),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isArabic ? 'المستندات قيد المراجعة' : 'Documents Under Review',
                    style: const TextStyle(
                      color: Color(0xFFE0F2FE),
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isArabic
                        ? 'أوراقك قيد التدقيق حالياً من الإدارة. يمكنك ضبط ملاعبك وإعدادات الأسعار الآن.'
                        : 'Your docs are being audited by administration. You can configure your pitches & prices.',
                    style: TextStyle(
                      color: const Color(0xFFBAE6FD).withValues(alpha: 0.85),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/documentation');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(VSPRadius.sm),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                ),
                child: Text(
                  isArabic ? 'عرض' : 'View',
                  style: const TextStyle(
                    color: Color(0xFFE0F2FE),
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 3. مطلوب التوثيق (غير موثق أو تم رفض بعض الوثائق)
    final Color primaryColor = isRejected ? VSPColors.error : VSPColors.warning;
    final String title = isRejected
        ? (isArabic ? 'تم رفض بعض المستندات' : 'Documents Need Attention')
        : (isArabic ? 'منشأتك غير موثقة بعد' : 'Facility Verification Required');
    final String subtitle = isRejected
        ? (isArabic ? 'يرجى مراجعة وتحديث الوثائق المطلوبة لاعتماد منشأتك.' : 'Please update your uploaded documents for approval.')
        : (isArabic ? 'يرجى رفع السجل التجاري والبطاقة الضريبية لتفعيل ظهور ملاعبك للاعبين.' : 'Upload commercial registry & tax card to make your pitches visible to players.');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.16),
            primaryColor.withValues(alpha: 0.06),
          ],
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
        ),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.38),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRejected ? Iconsax.warning_2_copy : Iconsax.security_safe_copy,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isRejected ? const Color(0xFFFCA5A5) : const Color(0xFFFEF3C7),
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isRejected ? Colors.white70 : const Color(0xFFFDE68A).withValues(alpha: 0.85),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/documentation');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(VSPRadius.sm),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                isArabic ? 'توثيق الآن' : 'Verify Now',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// تنبيه انتهاء الاشتراك
class OwnerSubscriptionExpiredAlert extends StatelessWidget {
  final bool isArabic;
  final VoidCallback onRenew;

  const OwnerSubscriptionExpiredAlert({
    super.key,
    required this.isArabic,
    required this.onRenew,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: VSPColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: VSPColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Iconsax.warning_2_copy,
            color: VSPColors.error,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isArabic
                  ? 'انتهت صلاحية الاشتراك. يرجى التجديد لتفعيل الحجوزات.'
                  : 'Subscription expired. Renew now to activate bookings.',
              style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: onRenew,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(VSPRadius.sm),
              ),
              child: Text(
                isArabic ? 'تجديد' : 'Renew',
                style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// بنر العد التنازلي للتجربة المجانية (يظهر فقط في آخر 10 أيام: اليوم 51 إلى 60)
class OwnerTrialEndingSoonAlert extends StatelessWidget {
  final int remainingDays;
  final bool isArabic;
  final VoidCallback onUpgrade;

  const OwnerTrialEndingSoonAlert({
    super.key,
    required this.remainingDays,
    required this.isArabic,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final String daysText;
    if (remainingDays <= 0) {
      daysText = isArabic ? 'اليوم الأخير' : 'Last day';
    } else if (remainingDays == 1) {
      daysText = isArabic ? 'يوم واحد' : '1 day';
    } else if (remainingDays == 2) {
      daysText = isArabic ? 'يومان' : '2 days';
    } else {
      daysText = isArabic ? '$remainingDays أيام' : '$remainingDays days';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Iconsax.timer_1_copy,
            color: Color(0xFFF59E0B),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isArabic
                      ? 'باقي $daysText على انتهاء التجربة المجانية'
                      : '$daysText left in your free trial',
                  style: const TextStyle(
                    color: Color(0xFFFEF3C7),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isArabic
                      ? 'قم بالترقية الآن لضمان استمرار استقبال الحجوزات دون انقطاع.'
                      : 'Upgrade now to ensure uninterrupted booking reception.',
                  style: const TextStyle(
                    color: Color(0xFFFDE68A),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onUpgrade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(VSPRadius.sm),
              ),
              child: Text(
                isArabic ? 'ترقية' : 'Upgrade',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
