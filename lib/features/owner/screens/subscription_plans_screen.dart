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

/// شاشة اشتراك المالكين: استخدام مجاني + Pro المدفوع + تجربة Pro
class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  bool _isPaying = false;
  final OwnerSubscriptionRepository _subscriptionRepository = OwnerSubscriptionRepository();
  Map<String, dynamic>? _freePlan;
  Map<String, dynamic>? _proPlan;
  bool _isPlansLoading = true;
  bool _hasPlansError = false;
  int _plansRequestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final requestGeneration = ++_plansRequestGeneration;
    if (mounted) {
      setState(() {
        _isPlansLoading = true;
        _hasPlansError = false;
      });
    }
    try {
      final plans = await _subscriptionRepository.fetchPublicPlans();
      if (!mounted || requestGeneration != _plansRequestGeneration) return;
      Map<String, dynamic>? freePlan;
      Map<String, dynamic>? proPlan;
      for (final plan in plans) {
        if (plan['code'] == 'basic') freePlan = plan;
        if (plan['code'] == 'pro') proPlan = plan;
      }
      if (freePlan == null || proPlan == null) {
        throw StateError('subscription_plan_missing');
      }
      if (!mounted || requestGeneration != _plansRequestGeneration) return;
      setState(() {
        _freePlan = freePlan;
        _proPlan = proPlan;
        _isPlansLoading = false;
        _hasPlansError = false;
      });
    } catch (e) {
      debugPrint('Failed to load public subscription plans: $e');
      if (!mounted || requestGeneration != _plansRequestGeneration) return;
      setState(() {
        _isPlansLoading = false;
        _hasPlansError = true;
      });
    }
  }

  List<String> _featureLabels(Map<String, dynamic>? rawFeatures, bool isArabic) {
    final features = rawFeatures ?? const <String, dynamic>{};
    final labels = <String>[];
    const featureCopy = <String, List<String>>{
      'cash_booking': ['إدارة الحجوزات النقدية', 'Manage cash bookings'],
      'online_booking': ['إدارة الحجوزات الإلكترونية', 'Manage online bookings'],
      'shift_management': ['إدارة الورديات والمواعيد', 'Shift and slot management'],
      'no_show_protection': ['الحماية من عدم الحضور', 'No-show protection'],
      'tournament_management': ['إدارة البطولات', 'Tournament management'],
      'ai_insights': ['تحليلات ذكية وVSP Copilot', 'AI insights and VSP Copilot'],
      'excel_reports': ['تقارير Excel', 'Excel reports'],
      'search_priority_boost': ['أولوية الظهور في البحث', 'Priority search visibility'],
      'whatsapp_confirmation': ['تأكيدات عبر واتساب', 'WhatsApp confirmations'],
      'atomic_booking': ['تأكيد حجوزات ذري', 'Atomic booking confirmation'],
    };
    for (final entry in featureCopy.entries) {
      if (features[entry.key] == true) {
        labels.add(entry.value[isArabic ? 0 : 1]);
      }
    }
    final support = features['support']?.toString();
    if (support == 'priority_24_7') {
      labels.add(isArabic ? 'أولوية في التواصل مع الدعم الفني' : 'Priority access to technical support');
    } else if (support == 'standard') {
      labels.add(isArabic ? 'دعم فني قياسي' : 'Standard support');
    }
    return labels;
  }

  String _planDescription(Map<String, dynamic> plan, bool isArabic) {
    final value = plan[isArabic ? 'description_ar' : 'description_en']?.toString().trim();
    return value == null || value.isEmpty
        ? (isArabic ? 'تفاصيل الباقة غير متاحة حالياً.' : 'Plan details are currently unavailable.')
        : value;
  }

  int _planNumber(Map<String, dynamic> plan, String key, {int fallback = 0}) {
    final value = plan[key];
    return value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final userModel = context.watch<AuthProvider>().userModel;
    final isPro = userModel?.isProPlan == true;
    final isTrialActive = userModel?.isInActiveTrial == true;
    final hasProAccess = isPro || isTrialActive;
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
        child: _isPlansLoading
            ? const Center(child: CircularProgressIndicator(color: VSPColors.accent))
            : _hasPlansError || _freePlan == null || _proPlan == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(VSPSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.info_circle_copy, color: VSPColors.warning, size: 32),
                          const SizedBox(height: VSPSpacing.md),
                          Text(
                            isArabic
                                ? 'تعذر تحميل أسعار ومزايا الباقات من النظام. لن نعرض أسعاراً قديمة.'
                                : 'Could not load current plan prices and features. Outdated prices will not be shown.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: VSPSpacing.md),
                          TextButton(
                            onPressed: _loadPlans,
                            child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
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
                              ? 'تجربة Pro مفعلة (متبقي $trialDaysRemaining يوم). تشمل كافة مزايا Pro، وتعود تلقائياً للحساب المجاني بعد انتهاء المدة.'
                              : 'Pro Trial is active ($trialDaysRemaining days left). Reverts to Free after trial ends.',
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

              // Free and Pro plan content is sourced from public_subscription_plans.
              _buildFreePlanCard(context, isArabic, hasProAccess, isTrialActive, _freePlan!),

              const SizedBox(height: 18),

              _buildProPlanCard(context, isArabic, hasProAccess, isTrialActive, _proPlan!),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildFreePlanCard(
    BuildContext context,
    bool isArabic,
    bool hasProAccess,
    bool isTrialActive,
    Map<String, dynamic> plan,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.xl),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(
          color: !hasProAccess ? VSPColors.accent.withValues(alpha: 0.45) : VSPColors.divider,
          width: !hasProAccess ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'مجاني' : 'Free',
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
            _planDescription(plan, isArabic),
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
                isArabic
                    ? '${_planNumber(plan, 'monthly_price')} جنيه'
                    : '${_planNumber(plan, 'monthly_price')} EGP',
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
            ..._featureLabels(plan['features'] is Map ? Map<String, dynamic>.from(plan['features'] as Map) : null, isArabic),
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
              color: !hasProAccess ? VSPColors.accent.withValues(alpha: 0.12) : VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.sm),
              border: Border.all(
                color: !hasProAccess ? VSPColors.accent.withValues(alpha: 0.35) : VSPColors.divider,
              ),
            ),
            child: Text(
              !hasProAccess
                  ? (isArabic ? 'حسابك المجاني الحالي' : 'Your current free account')
                  : isTrialActive
                      ? (isArabic ? 'الخطة المجانية متاحة دائماً' : 'The free plan remains available')
                      : (isArabic ? 'مضمنة مع حسابك مجاناً' : 'Included with your account for free'),
              style: TextStyle(
                color: !hasProAccess ? VSPColors.accent : VSPColors.textSecondary,
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
    Map<String, dynamic> plan,
  ) {
    final monthlyPrice = _planNumber(plan, 'monthly_price');
    final annualPrice = _planNumber(plan, 'yearly_price');
    final annualSavings = monthlyPrice * 12 - annualPrice;
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
                isArabic ? 'Pro' : 'Pro',
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
                  isArabic
                      ? '${_planNumber(plan, 'max_stadiums')} ملاعب + Copilot'
                      : '${_planNumber(plan, 'max_stadiums')} Stadiums + Copilot',
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
            _planDescription(plan, isArabic),
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
                isArabic
                    ? '${_planNumber(plan, 'monthly_price')} جنيه'
                    : '${_planNumber(plan, 'monthly_price')} EGP',
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
            ..._featureLabels(plan['features'] is Map ? Map<String, dynamic>.from(plan['features'] as Map) : null, isArabic),
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
            if (!isTrialActive && _planNumber(plan, 'trial_days') > 0) ...[
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
                    isArabic
                        ? 'جرّب Pro لمدة ${_planNumber(plan, 'trial_days')} أيام مجاناً'
                        : 'Try Pro for ${_planNumber(plan, 'trial_days')} days free',
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
                        isArabic
                            ? 'اشترك الآن (${_planNumber(plan, 'monthly_price')} جنيه / شهر)'
                            : 'Subscribe Now (${_planNumber(plan, 'monthly_price')} EGP/mo)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
            if (annualPrice > 0) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: _isPaying
                      ? null
                      : () => _startSubscriptionPayment(context, 'annual', isArabic),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VSPColors.textPrimary,
                    side: const BorderSide(color: VSPColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                    ),
                  ),
                  child: Text(
                    isArabic
                        ? 'اشتراك سنوي • $annualPrice جنيه'
                        : 'Annual subscription • $annualPrice EGP',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
              if (annualSavings > 0) ...[
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    isArabic
                        ? 'وفّر $annualSavings جنيه مقارنة بالدفع الشهري'
                        : 'Save $annualSavings EGP compared with monthly billing',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: VSPColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
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
              ? 'تم تفعيل تجربة Pro لمدة ${_planNumber(_proPlan ?? const <String, dynamic>{}, 'trial_days')} أيام بنجاح.'
              : 'Your ${_planNumber(_proPlan ?? const {}, 'trial_days')}-day Pro trial is now active.',
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
