import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../screens/subscription_plans_screen.dart';
import '../../services/facility_onboarding_service.dart';

/// Modal bottom sheet prompting the owner to upgrade their subscription
/// when they reach the maximum allowed stadiums.
class FacilityUpgradeBottomSheet extends StatelessWidget {
  final bool isAr;
  final UserModel user;

  const FacilityUpgradeBottomSheet({
    super.key,
    required this.isAr,
    required this.user,
  });

  /// Static helper to display the upgrade bottom sheet safely.
  static Future<void> show(
    BuildContext context, {
    required bool isAr,
    required UserModel user,
  }) async {
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => FacilityUpgradeBottomSheet(isAr: isAr, user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(VSPRadius.xl),
          topRight: Radius.circular(VSPRadius.xl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 16
            : 36,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // ─── Handle Bar ───
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: VSPColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Icon ───
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: VSPColors.accent, width: 1.5),
            ),
            child: const Icon(Iconsax.crown_copy, color: VSPColors.accent, size: 32),
          ),
          const SizedBox(height: 16),

          // ─── Title ───
          Text(
            isAr ? 'ترقية الباقة لإضافة ملاعب أخرى' : 'Upgrade Plan to Add More Stadiums',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),

          // ─── Current Plan Badge ───
          _buildCurrentPlanBadge(isAr, user),
          const SizedBox(height: 12),

          // ─── Description ───
          Text(
            isAr
                ? 'فترتك الحالية تتيح تشغيل ملعب واحد فقط (1).\n\nللإضافة والتوسع حتى 3 ملاعب كاملة، يرجى الترقية للباقة الاحترافية (1000 ج.م / شهرياً).'
                : 'Your current plan allows 1 stadium only.\n\nTo operate up to 3 full stadiums, please upgrade to the Pro Plan (1000 EGP/month).',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VSPColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // ─── What you get ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                _FeatureRow(
                  icon: Iconsax.buildings_copy,
                  text: isAr ? 'إضافة وتشغيل حتى 3 ملاعب كاملة' : 'Operate up to 3 full stadiums',
                ),
                const SizedBox(height: 8),
                _FeatureRow(
                  icon: Iconsax.chart_1_copy,
                  text: isAr
                      ? 'أولوية الظهور في نتائج البحث للاعبين'
                      : 'Priority search boost in governorate results',
                ),
                const SizedBox(height: 8),
                _FeatureRow(
                  icon: Iconsax.headphones_copy,
                  text: isAr
                      ? 'دعم فني وأولوية تشغيلية على مدار الساعة'
                      : '24/7 Priority owner support',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Subscribe Button ───
          PrimaryButton(
            text: isAr ? ' اشترك الآن في الباقة الاحترافية' : ' Upgrade to Pro Now',
            color: Colors.amber,
            textColor: Colors.black,
            onPressed: () async {
              // Capture navigator reference before pop to avoid deactivation issues
              final navigator = Navigator.of(context);
              navigator.pop();
              await navigator.push(
                MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()),
              );
            },
          ),
          const SizedBox(height: 12),

          // ─── Cancel ───
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isAr ? 'ليس الآن' : 'Not now',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCurrentPlanBadge(bool isAr, UserModel user) {
    final bool isTrial = user.isInActiveTrial;
    final int daysRemaining = FacilityOnboardingService.getTrialDaysRemaining(user);
    final String planLabel = FacilityOnboardingService.getPlanLabel(
      user: user,
      isArabic: isAr,
    );

    final String daysText = isTrial
        ? (isAr
            ? 'متبقي $daysRemaining يوم من الفترة المجانية'
            : '$daysRemaining days remaining in free trial')
        : '';

    return Column(
      children: [
        Text(
          isAr ? 'باقتك الحالية' : 'Current Plan',
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          planLabel,
          style: const TextStyle(
            color: VSPColors.accent,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (daysText.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            daysText,
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.amber, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ],
    );
  }
}
