import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../core/utils/vsp_feedback.dart';
import 'package:url_launcher/url_launcher.dart';

/// شاشة باقات اشتراك المالكين بتصميم هادئ ومبسط ونظيف (Minimalist Obsidian + Emerald)
class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  List<Map<String, dynamic>> _plans = [];
  bool _isAnnual = false;
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    try {
      final res = await Supabase.instance.client
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);
      if (mounted) {
        setState(() {
          _plans = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (_) {}
  }

  void _startCountdown() {
    _updateRemainingTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateRemainingTime();
      }
    });
  }

  void _updateRemainingTime() {
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user == null) return;

    DateTime? targetDate = user.subscriptionExpiresAt ?? user.effectiveTrialEndsAt;

    if (targetDate != null) {
      final now = DateTime.now();
      if (targetDate.isAfter(now)) {
        setState(() {
          _remainingTime = targetDate.difference(now);
        });
      } else {
        setState(() {
          _remainingTime = Duration.zero;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final userModel = Provider.of<AuthProvider>(context).userModel;
    final isPro = userModel?.isProPlan == true;
    Map<String, dynamic>? planByCode(String code) {
      for (final plan in _plans) {
        if (plan['code']?.toString() == code) return plan;
      }
      return null;
    }
    final proPlan = planByCode('pro');
    final proMonthly = (proPlan?['monthly_price'] as num?)?.toDouble() ?? 1000;
    final proAnnual = (proPlan?['yearly_price'] as num?)?.toDouble() ?? 11000;
    final price = _isAnnual ? proAnnual : proMonthly;

    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(isArabic ? 'اشتراك المالك' : 'Owner Subscription',
            style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              if (userModel != null) _buildCompactStatusHeader(userModel, isArabic),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.card), border: Border.all(color: VSPColors.divider)),
                child: Row(
                  children: [
                    const Icon(Iconsax.timer_1_copy, color: VSPColors.accent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      isArabic ? 'تسجيل المالك مجاني، ولك 7 أيام تجربة قبل الاشتراك.' : 'Owner registration is free, with a 7-day trial before subscription.',
                      style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(VSPSpacing.xl),
                decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.card),
                    border: Border.all(color: VSPColors.proAccent.withValues(alpha: 0.45), width: 1.2)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isArabic ? 'الباقة الاحترافية' : 'Pro Plan',
                            style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(color: VSPColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(VSPRadius.xs)),
                          child: Text(isArabic ? 'شهر مجاني سنوياً' : '1 month free annually',
                              style: const TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 42,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: VSPColors.surfaceAlt, borderRadius: BorderRadius.circular(VSPRadius.full)),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _isPaying ? null : () => setState(() => _isAnnual = false),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: !_isAnnual ? VSPColors.accent : Colors.transparent, borderRadius: BorderRadius.circular(VSPRadius.full)),
                                child: Text(isArabic ? 'شهري' : 'Monthly',
                                    style: TextStyle(color: !_isAnnual ? Colors.black : VSPColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _isPaying ? null : () => setState(() => _isAnnual = true),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: _isAnnual ? VSPColors.accent : Colors.transparent, borderRadius: BorderRadius.circular(VSPRadius.full)),
                                child: Text(isArabic ? 'سنوي' : 'Annual',
                                    style: TextStyle(color: _isAnnual ? Colors.black : VSPColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(price.toStringAsFixed(0) + ' ' + (isArabic ? 'ج.م' : 'EGP'),
                            style: const TextStyle(color: VSPColors.textPrimary, fontSize: 30, fontWeight: FontWeight.w900)),
                        const SizedBox(width: 7),
                        Text(_isAnnual ? (isArabic ? 'سنوياً' : 'per year') : (isArabic ? 'شهرياً' : 'per month'),
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                    if (_isAnnual) ...[
                      const SizedBox(height: 5),
                      Text(isArabic ? 'بدلاً من 12,000 ج.م — شهر مجاني' : 'Instead of 12,000 EGP — one month free',
                          style: const TextStyle(color: VSPColors.accent, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(height: 16),
                    const Divider(color: VSPColors.divider, height: 1),
                    const SizedBox(height: 14),
                    ...[
                      isArabic ? 'VSP Copilot وإحصاءات الملاعب الذكية' : 'VSP Copilot and smart stadium insights',
                      isArabic ? 'تشغيل وإدارة حتى 3 ملاعب' : 'Operate up to 3 stadiums',
                      isArabic ? 'إدارة الحجوزات النقدية والأونلاين' : 'Manage cash and online bookings',
                      isArabic ? 'تقارير مالية وسجل حساب واضح' : 'Clear financial reports and ledger',
                    ].map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 15),
                          const SizedBox(width: 8),
                          Expanded(child: Text(feature, style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12.5, height: 1.35))),
                        ],
                      ),
                    )),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: isPro
                          ? Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(VSPRadius.sm), border: Border.all(color: VSPColors.divider)),
                              child: Text(isArabic ? 'اشتراكك الحالي مفعّل' : 'Your subscription is active',
                                  style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.5)),
                            )
                          : ElevatedButton(
                              onPressed: _isPaying ? null : () => _startSubscriptionPayment(context, _isAnnual ? 'annual' : 'monthly', isArabic),
                              style: ElevatedButton.styleFrom(backgroundColor: VSPColors.accent, foregroundColor: Colors.black, elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm))),
                              child: _isPaying
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                  : Text(isArabic ? 'الدفع عبر Paymob' : 'Pay with Paymob',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// شريط حالة الاشتراك الهادئ والمضغوط
  Widget _buildCompactStatusHeader(UserModel user, bool isArabic) {
    final bool isTrial = user.isInActiveTrial;
    final bool isGrace = user.isInGracePeriod;
    final bool isExpired = user.isPlanExpired;

    final days = _remainingTime.inDays;
    final hours = _remainingTime.inHours % 24;

    final String planLabelText = isArabic
        ? (user.isProPlan
            ? 'الباقة الاحترافية'
            : (user.subscriptionPlan == 'basic'
                ? 'الباقة الأساسية'
                : 'الفترة التجريبية'))
        : (user.isProPlan
            ? 'Pro Plan'
            : (user.subscriptionPlan == 'basic'
                ? 'Basic Plan'
                : 'Free Trial'));

    final String stateLabel = isTrial
        ? (isArabic ? 'تجريبية نشطة' : 'Active Trial')
        : isGrace
            ? (isArabic ? 'فترة سماح' : 'Grace Period')
            : isExpired
                ? (isArabic ? 'منتهية' : 'Expired')
                : (isArabic ? 'نشطة' : 'Active');

    final String stateMessage = isTrial
        ? (isArabic ? 'أنت داخل الفترة التجريبية الحالية.' : 'You are in the current free-trial period.')
        : isGrace
            ? (isArabic
                ? 'لديك مهلة محدودة لتجديد الاشتراك وإعادة التفعيل.'
                : 'You have a limited grace period to renew and reactivate.')
            : isExpired
                ? (isArabic ? 'جدد الاشتراك لإعادة تفعيل تشغيل الملاعب.' : 'Renew to reactivate stadium operations.')
                : (isArabic ? 'اشتراكك الحالي فعال.' : 'Your current subscription is active.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: isExpired ? VSPColors.error.withValues(alpha: 0.3) : VSPColors.divider,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isExpired ? Iconsax.warning_2_copy : Iconsax.timer_1_copy,
                color: isExpired ? VSPColors.error : VSPColors.accent,
                size: 18,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic
                        ? 'الحالة: $stateLabel'
                        : 'Status: $stateLabel',
                    style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isTrial || (!isGrace && !isExpired)
                        ? (isArabic ? 'الخطة: $planLabelText • المتبقي: $days يوم و $hours ساعة' : 'Plan: $planLabelText • Remaining: $days d $hours h')
                        : stateMessage,
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isGrace || isExpired)
                  ? VSPColors.error.withValues(alpha: 0.12)
                  : VSPColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(VSPRadius.full),
            ),
            child: Text(
              stateLabel,
              style: TextStyle(
                color: (isGrace || isExpired) ? VSPColors.error : VSPColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// كارد الباقة الموحد الهادئ والمبسط
  Widget _buildPlanCard({
    required String title,
    required String priceText,
    required String periodText,
    required String badgeText,
    required Color badgeColor,
    required List<String> features,
    required String buttonText,
    required VoidCallback? onSelect,
    required bool isArabic,
    bool isHighlighted = false,
    bool isCurrentPlan = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(VSPSpacing.xl),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(
          color: isHighlighted ? VSPColors.proAccent.withValues(alpha: 0.45) : VSPColors.divider,
          width: isHighlighted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Title & Clean Top Badge ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(VSPRadius.xs),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 0.6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Price Row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                priceText,
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  periodText.startsWith('مجاناً') || periodText.startsWith('Free')
                      ? periodText
                      : '/ $periodText',
                  style: const TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: VSPColors.divider, height: 1),
          const SizedBox(height: 14),

          // ── Features List (Clean Bullets) ──
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(
                          color: VSPColors.textPrimary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 16),

          // ── Clean CTA Button ──
          SizedBox(
            width: double.infinity,
            height: 44,
            child: isCurrentPlan
                ? Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                      border: Border.all(color: VSPColors.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          buttonText,
                          style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ],
                    ),
                  )
                : ElevatedButton(
                    onPressed: onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isHighlighted ? VSPColors.accent : Colors.white.withValues(alpha: 0.08),
                      foregroundColor: isHighlighted ? Colors.black : VSPColors.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.sm),
                        side: isHighlighted
                            ? BorderSide.none
                            : const BorderSide(color: VSPColors.divider, width: 1),
                      ),
                    ),
                    child: Text(
                      buttonText,
                      style: TextStyle(
                        color: isHighlighted ? Colors.black : VSPColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _startSubscriptionPayment(BuildContext context, String billingPeriod, bool isArabic) async {
    setState(() => _isPaying = true);
    try {
      final order = await Supabase.instance.client.rpc(
        'create_owner_subscription_order',
        params: {'p_plan_code': 'pro', 'p_billing_period': billingPeriod},
      );
      final orderData = Map<String, dynamic>.from(order as Map);
      if (orderData['success'] != true || orderData['order_id'] == null) throw Exception('subscription_order_failed');

      final response = await Supabase.instance.client.functions.invoke(
        'create_paymob_intention',
        body: {'subscription_order_id': orderData['order_id']},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final checkoutUrl = data['checkout_url']?.toString();
      if (checkoutUrl == null || checkoutUrl.isEmpty) throw Exception('checkout_url_missing');

      final launched = await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
      if (!launched) throw Exception('paymob_launch_failed');

      if (context.mounted) {
        VSPFeedback.showSuccess(context, isArabic
            ? 'أكمل الدفع عبر Paymob. سيتم تفعيل الاشتراك بعد تأكيد العملية.'
            : 'Complete payment in Paymob. Your subscription will activate after confirmation.');
      }
    } catch (_) {
      if (context.mounted) {
        VSPFeedback.showError(context, isArabic ? 'تعذر بدء الدفع حالياً. حاول مرة أخرى.' : 'Unable to start payment right now. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

}
