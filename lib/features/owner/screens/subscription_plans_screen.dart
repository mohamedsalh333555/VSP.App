import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/utils/app_error_handler.dart';
import '../../../core/repositories/owner_subscription_repository.dart';
import 'package:url_launcher/url_launcher.dart';

/// شاشة باقات اشتراك المالكين بالنموذج التجاري المعتمد نهائياً (Basic Free 0 EGP / Pro 1000 EGP / Pro 7-Day Trial)
class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  bool _isPaying = false;
  final OwnerSubscriptionRepository _subscriptionRepository = OwnerSubscriptionRepository();

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final userModel = context.watch<AuthProvider>().userModel;
    final isPro = userModel?.isProPlan == true;
    final isTrialActive = userModel?.isInActiveTrial == true;
    final trialDaysRemaining = isTrialActive && userModel?.trialEndsAt != null
        ? userModel!.trialEndsAt!.difference(DateTime.now()).inDays + 1
        : 0;

    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(
          isArabic ? 'باقات اشتراك الملاعب' : 'Pitch Subscription Plans',
          style: const TextStyle(
            color: VSPColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── COMMERCIAL STRATEGY BANNER ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(VSPRadius.card),
                  border: Border.all(color: VSPColors.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(VSPRadius.sm),
                      ),
                      child: const Icon(Iconsax.flash_copy, color: VSPColors.accent, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        isArabic
                            ? 'ابدأ مجانًا، وادفع عندما تحتاج مزايا أكثر أو عدد ملاعب أكبر.'
                            : 'Start for free, and upgrade when you need more features or stadiums.',
                        style: const TextStyle(
                          color: VSPColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (isTrialActive) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: VSPColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(VSPRadius.card),
                    border: Border.all(color: VSPColors.accent.withValues(alpha: 0.40)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.timer_1_copy, color: VSPColors.accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isArabic
                              ? 'تجربة Pro مفعلة (متبقي $trialDaysRemaining يوم). تشمل كافة مزايا Pro، وتعود تلقائياً للباقة الأساسية المجانية بعد انتهاء المدة.'
                              : 'Pro Trial is active ($trialDaysRemaining days left). Reverts to Basic Free after trial ends.',
                          style: const TextStyle(
                            color: VSPColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // ── BASIC PLAN CARD (FREE FOREVER - 0 EGP - 1 STADIUM) ──
              _buildBasicPlanCard(context, isArabic, isPro),

              const SizedBox(height: 18),

              // ── PRO PLAN CARD (1000 EGP / MONTH - 3 STADIUMS - 7-DAY TRIAL) ──
              _buildProPlanCard(context, isArabic, isPro, isTrialActive),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicPlanCard(BuildContext context, bool isArabic, bool isPro) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.xl),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(
          color: !isPro ? VSPColors.accent.withValues(alpha: 0.45) : VSPColors.divider,
          width: !isPro ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'الباقة الأساسية' : 'Basic Plan',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(VSPRadius.chip),
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.35)),
                ),
                child: Text(
                  isArabic ? 'مجاني بالكامل' : 'Completely Free',
                  style: const TextStyle(
                    color: VSPColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'إدارة كاملة لملعبك وحجوزاتك بدون أي رسوم اشتراك مدى الحياة.'
                : 'Complete stadium & booking management with zero subscription fees for life.',
            style: const TextStyle(
              color: VSPColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                isArabic ? '0 جنيه' : '0 EGP',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'مدى الحياة' : 'forever',
                style: const TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: VSPColors.divider, height: 1),
          const SizedBox(height: 14),
          ...[
            isArabic ? 'تشغيل وإدارة ملعب واحد (1 Stadium)' : 'Operate & manage 1 stadium',
            isArabic ? 'إدارة الحجوزات النقدية والإلكترونية' : 'Manage cash & online bookings',
            isArabic ? 'إدارة الورديات وتعيين المواعيد' : 'Shift management & slot scheduling',
            isArabic ? 'حماية من عدم الحضور وسجل حساب للملعب' : 'No-show protection & financial ledger',
            isArabic ? 'دعم فني قياسي' : 'Standard customer support',
          ].map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Iconsax.tick_circle_copy, color: VSPColors.textSecondary, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        color: VSPColors.textPrimary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: !isPro ? VSPColors.accent.withValues(alpha: 0.12) : VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.sm),
              border: Border.all(
                color: !isPro ? VSPColors.accent.withValues(alpha: 0.35) : VSPColors.divider,
              ),
            ),
            child: Text(
              !isPro
                  ? (isArabic ? 'باقتك الحالية المفعلة (مجاناً)' : 'Your Active Plan (Free)')
                  : (isArabic ? 'مشمولة تلقائياً مع حسابك' : 'Included with your account'),
              style: TextStyle(
                color: !isPro ? VSPColors.accent : VSPColors.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProPlanCard(
    BuildContext context,
    bool isArabic,
    bool isPro,
    bool isTrialActive,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.xl),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(
          color: isPro ? VSPColors.accent : VSPColors.proAccent.withValues(alpha: 0.45),
          width: isPro ? 1.5 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'الباقة الاحترافية' : 'Pro Plan',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: VSPColors.proAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(VSPRadius.chip),
                  border: Border.all(color: VSPColors.proAccent.withValues(alpha: 0.45)),
                ),
                child: Text(
                  isArabic ? '3 ملاعب + Copilot' : '3 Stadiums + Copilot',
                  style: const TextStyle(
                    color: VSPColors.proAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'أقصى طاقة تشغيلية مع المزايا الذكية لإدارة حتى 3 ملاعب.'
                : 'Maximum operational capacity with smart features to operate up to 3 stadiums.',
            style: const TextStyle(
              color: VSPColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                isArabic ? '1000 جنيه' : '1000 EGP',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isArabic ? '/ شهرياً' : '/ month',
                style: const TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: VSPColors.divider, height: 1),
          const SizedBox(height: 14),
          ...[
            isArabic ? 'تشغيل وإدارة حتى 3 ملاعب (3 Stadiums)' : 'Operate up to 3 stadiums',
            isArabic ? 'ذكاء اصطناعي VSP Copilot وقرارات تشغيلية' : 'VSP Copilot and operational decisions',
            isArabic ? 'تقارير إكسل ومقارنة أداء الملاعب' : 'Excel reports & stadium performance comparisons',
            isArabic ? 'أولوية ظهور الملاعب في نتائج البحث' : 'Priority visibility in search results',
            isArabic ? 'دعم فني مخصص على مدار الساعة' : '24/7 dedicated support',
          ].map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        color: VSPColors.textPrimary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (isPro && !isTrialActive)
            Container(
              width: double.infinity,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VSPRadius.sm),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.40)),
              ),
              child: Text(
                isArabic ? 'اشتراك Pro مفعّل' : 'Pro Subscription Active',
                style: const TextStyle(
                  color: VSPColors.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            )
          else ...[
            if (!isTrialActive) ...[
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: _isPaying ? null : () => _startOwnerTrial(context, isArabic),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VSPColors.accent,
                    backgroundColor: VSPColors.accent.withValues(alpha: 0.08),
                    side: BorderSide(color: VSPColors.accent.withValues(alpha: 0.45)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                    ),
                  ),
                  child: Text(
                    isArabic ? 'جرّب Pro لمدة 7 أيام مجاناً' : 'Try Pro 7 Days for Free',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _isPaying
                    ? null
                    : () => _startSubscriptionPayment(context, 'monthly', isArabic),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSPColors.accent,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VSPRadius.sm),
                  ),
                ),
                child: _isPaying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        isArabic ? 'اشترك الآن (1000 جنيه / شهر)' : 'Subscribe Now (1000 EGP/mo)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startOwnerTrial(BuildContext context, bool isArabic) async {
    final auth = context.read<AuthProvider>();
    setState(() => _isPaying = true);
    try {
      final data = await _subscriptionRepository.startProTrial();
      if (data['success'] != true) {
        throw Exception(data['error']?.toString() ?? 'trial_start_failed');
      }
      await auth.refreshProfile();
      if (context.mounted) {
        VSPFeedback.showSuccess(
          context,
          isArabic
              ? 'تم تفعيل تجربة Pro لمدة 7 أيام بنجاح.'
              : 'Your 7-day Pro trial is now active.',
        );
      }
    } catch (e) {
      if (context.mounted) VSPFeedback.showError(context, AppErrorHandler.formatError(e, isArabic: isArabic));
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  Future<void> _startSubscriptionPayment(
    BuildContext context,
    String billingPeriod,
    bool isArabic,
  ) async {
    setState(() => _isPaying = true);
    try {
      final orderData = await _subscriptionRepository.createProOrder(
        billingPeriod: billingPeriod,
      );
      if (orderData['success'] != true || orderData['order_id'] == null) {
        throw Exception(orderData['message'] ?? 'subscription_order_failed');
      }

      final checkoutUrl = await _subscriptionRepository.createPaymobCheckout(
        subscriptionOrderId: orderData['order_id'].toString(),
      );

      final launched = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw Exception('paymob_launch_failed');

      if (context.mounted) {
        VSPFeedback.showSuccess(
          context,
          isArabic
              ? 'أكمل عملية الدفع عبر Paymob. سيتم تفعيل اشتراك Pro فور تأكيد السداد.'
              : 'Complete payment via Paymob. Pro will activate upon payment confirmation.',
        );
      }
    } catch (e) {
      if (context.mounted) VSPFeedback.showError(context, AppErrorHandler.formatError(e, isArabic: isArabic));
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }
}
