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
import '../../../core/repositories/app_settings_repository.dart';
import '../../../core/utils/vsp_launcher_utils.dart';

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
    final bool isPro = userModel?.isProPlan == true;
    final bool isTrialOrBasic = userModel?.isInActiveTrial == true ||
        (userModel?.subscriptionPlan == 'basic' && userModel?.hasActiveSubscription == true);

    Map<String, dynamic>? planByCode(String code) {
      for (final plan in _plans) {
        if (plan['code']?.toString() == code) return plan;
      }
      return null;
    }

    final basicPlan = planByCode('basic');
    final proPlan = planByCode('pro');
    final basicPrice = (basicPlan?['monthly_price'] as num?)?.toInt();
    final proPrice = (proPlan?['monthly_price'] as num?)?.toInt();
    final basicMaxStadiums = (basicPlan?['max_stadiums'] as num?)?.toInt();
    final proMaxStadiums = (proPlan?['max_stadiums'] as num?)?.toInt();

    if (basicPlan == null || proPlan == null || basicPrice == null || proPrice == null || basicMaxStadiums == null || proMaxStadiums == null) {
      return VSPScaffold(
        backgroundColor: VSPColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const VSPBackButton(),
          centerTitle: true,
          title: Text(isArabic ? 'باقات الاشتراك' : 'Subscription Plans'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              isArabic ? 'بيانات الباقات غير متاحة حالياً.' : 'Subscription plan data is currently unavailable.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 14),
            ),
          ),
        ),
      );
    }

    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(
          isArabic ? 'باقات الاشتراك' : 'Subscription Plans',
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
          children: [
            // ── 1. شريط حالة الاشتراك الهادئ ──
            if (userModel != null) _buildCompactStatusHeader(userModel, isArabic),

            const SizedBox(height: 16),

            // ── 2. الباقة الأساسية (Basic Plan) ──
            _buildPlanCard(
              title: isArabic ? 'الباقة الأساسية' : 'Basic Plan',
              priceText: isTrialOrBasic && userModel?.isInActiveTrial == true
                  ? (isArabic ? '0 ج.م' : '0 EGP')
                  : (isArabic ? '$basicPrice ج.م' : '$basicPrice EGP'),
              periodText: isTrialOrBasic && userModel?.isInActiveTrial == true
                  ? (isArabic ? 'مجاناً حالياً ($basicPrice ج.م شهرياً بعد انتهاء التجربة)' : 'Free now ($basicPrice EGP/mo after trial)')
                  : (isArabic ? 'شهرياً' : 'Monthly'),
              badgeText: isArabic ? 'أول سنة مجاناً' : 'First Year Free',
              badgeColor: VSPColors.accent,
              isHighlighted: false,
              isCurrentPlan: isTrialOrBasic,
              buttonText: isTrialOrBasic
                  ? (isArabic ? 'باقتك الحالية (فترة تجريبية مجانية)' : 'Current Plan (Free Trial)')
                  : (isArabic ? 'ابدأ مجاناً (أول سنة)' : 'Start Free (1st Year)'),
              features: [
                isArabic
                    ? 'تشغيل وإدارة حتى $basicMaxStadiums ${basicMaxStadiums == 1 ? 'ملعب واحد فقط' : 'ملاعب'}'
                    : 'Full operation for up to $basicMaxStadiums ${basicMaxStadiums == 1 ? 'stadium only' : 'stadiums'}',
                isArabic ? 'استقبال الحجوزات النقدية والأونلاين ومنع التضارب' : 'Accept Cash & Online bookings with conflict prevention',
                isArabic ? 'فترة تجريبية مجانية سنة كاملة لتقييم المنظومة' : 'Full 1-year free evaluation period',
                isArabic ? 'تنظيم وإدارة البطولات والكؤوس لجميع الفرق مجاناً' : 'Free Tournament creation & cup management',
              ],
              onSelect: () => _contactAdminForUpgrade(context, 'Basic ($basicPrice EGP)', isArabic),
              isArabic: isArabic,
            ),

            const SizedBox(height: VSPSpacing.lg),

            // ── 3. الباقة الاحترافية (Pro Plan) ──
            _buildPlanCard(
              title: isArabic ? 'الباقة الاحترافية' : 'Pro Plan',
              priceText: isArabic ? '$proPrice ج.م' : '$proPrice EGP',
              periodText: isArabic ? 'شهرياً' : 'Monthly',
              badgeText: isArabic ? 'الأكثر اختياراً' : 'Most Popular',
              badgeColor: VSPColors.proAccent,
              isHighlighted: true,
              isCurrentPlan: isPro,
              buttonText: isPro
                  ? (isArabic ? 'باقتك الحالية المفعلة' : 'Current Active Plan')
                  : (isArabic ? 'ترقية للباقة الاحترافية' : 'Upgrade to Pro Plan'),
              features: [
                isArabic ? 'مساعد الذكاء الاصطناعي VSP Copilot لتحليل الأداء وتوقع الحجوزات' : 'VSP AI Copilot for smart pitch management & insights',
                isArabic
                    ? 'تشغيل وإدارة حتى $proMaxStadiums ملاعب كاملة'
                    : 'Operate up to $proMaxStadiums stadiums at full capacity',
                isArabic ? 'أولوية الظهور في نتائج البحث للاعبين بالمحافظة' : 'Priority search boost in governorate results',
                isArabic ? 'إرسال وصل الحجز الرسمي للعملاء عبر واتساب تلقائياً' : 'Automated WhatsApp digital booking receipts',
                isArabic ? 'تصدير السجل المالي والتقارير المحاسبية بضغطة زر' : '1-Click financial ledger & reports export',
                isArabic ? 'دعم فني وتثبيت تشغيلي ذو أولوية على مدار الساعة' : '24/7 Priority support & operational stability',
              ],
              onSelect: () => _contactAdminForUpgrade(context, 'Pro ($proPrice EGP)', isArabic),
              isArabic: isArabic,
            ),

            const SizedBox(height: 48),
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

  Future<void> _contactAdminForUpgrade(BuildContext context, String planName, bool isArabic) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userModel;
    final ownerName = user?.name ?? (isArabic ? 'المالك' : 'Owner');
    final ownerPhone = user?.phone ?? '';
    final ownerId = user?.uid ?? '';

    final message = isArabic
        ? 'مرحباً إدارة VSP، يرغب المالك: $ownerName (هاتف: $ownerPhone - حساب: $ownerId) في تفعيل / ترقية حسابه إلى باقة $planName.'
        : 'Hi VSP Admin, owner: $ownerName (Phone: $ownerPhone - ID: $ownerId) wants to subscribe / upgrade to $planName plan.';
    try {
      final settings = await AppSettingsRepository().getSettings();
      if (!context.mounted) return;
      final phone = settings.whatsappNumber.isNotEmpty
          ? settings.whatsappNumber
          : (settings.supportPhone.isNotEmpty ? settings.supportPhone : '201100229462');
      await VSPLauncherUtils.openWhatsApp(context, phone: phone, message: message);
    } catch (_) {
      if (context.mounted) {
        VSPFeedback.showSuccess(
            context, isArabic ? 'يرجى التواصل مع إدارة التطبيق لطلب الترقية.' : 'Please contact support to request upgrade.');
      }
    }
  }
}
