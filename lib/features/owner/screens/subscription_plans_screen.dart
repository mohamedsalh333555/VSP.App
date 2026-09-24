import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _startCountdown();
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

    return Scaffold(
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
                  : (isArabic ? '500 ج.م' : '500 EGP'),
              periodText: isTrialOrBasic && userModel?.isInActiveTrial == true
                  ? (isArabic ? 'مجاناً حالياً (500 ج.م شهرياً بعد انتهاء التجربة)' : 'Free now (500 EGP/mo after trial)')
                  : (isArabic ? 'شهرياً' : 'Monthly'),
              badgeText: isArabic ? 'أول سنة مجاناً' : 'First Year Free',
              badgeColor: VSPColors.accent,
              isHighlighted: false,
              isCurrentPlan: isTrialOrBasic,
              buttonText: isTrialOrBasic
                  ? (isArabic ? 'باقتك الحالية (فترة تجريبية مجانية)' : 'Current Plan (Free Trial)')
                  : (isArabic ? 'ابدأ مجاناً (أول سنة)' : 'Start Free (1st Year)'),
              features: [
                isArabic ? 'تشغيل وإدارة ملعب واحد فقط (1)' : 'Full operation for 1 stadium only',
                isArabic ? 'استقبال الحجوزات النقدية والأونلاين ومنع التضارب' : 'Accept Cash & Online bookings with conflict prevention',
                isArabic ? 'فترة تجريبية مجانية سنة كاملة لتقييم المنظومة' : 'Full 1-year free evaluation period',
                isArabic ? 'تنظيم وإدارة البطولات والكؤوس لجميع الفرق مجاناً' : 'Free Tournament creation & cup management',
              ],
              onSelect: () => _contactAdminForUpgrade(context, 'Basic (500 EGP)', isArabic),
              isArabic: isArabic,
            ),

            const SizedBox(height: VSPSpacing.lg),

            // ── 3. الباقة الاحترافية (Pro Plan) ──
            _buildPlanCard(
              title: isArabic ? 'الباقة الاحترافية' : 'Pro Plan',
              priceText: isArabic ? '1000 ج.م' : '1000 EGP',
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
                isArabic ? 'تشغيل وإدارة حتى 3 ملاعب كاملة' : 'Operate up to 3 stadiums at full capacity',
                isArabic ? 'أولوية الظهور في نتائج البحث للاعبين بالمحافظة' : 'Priority search boost in governorate results',
                isArabic ? 'إرسال وصل الحجز الرسمي للعملاء عبر واتساب تلقائياً' : 'Automated WhatsApp digital booking receipts',
                isArabic ? 'تصدير السجل المالي والتقارير المحاسبية بضغطة زر' : '1-Click financial ledger & reports export',
                isArabic ? 'دعم فني وتثبيت تشغيلي ذو أولوية على مدار الساعة' : '24/7 Priority support & operational stability',
              ],
              onSelect: () => _contactAdminForUpgrade(context, 'Pro (1000 EGP)', isArabic),
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
    final bool isExpired = user.isPlanExpired;
    final bool isTrial = user.isInActiveTrial;

    final days = _remainingTime.inDays;
    final hours = _remainingTime.inHours % 24;

    final String planLabelText = isArabic
        ? (user.isProPlan ? 'الباقة الاحترافية' : (isTrial ? 'فترة تجريبية' : 'الباقة الأساسية'))
        : (user.isProPlan ? 'Pro Plan' : (isTrial ? 'Free Trial' : 'Basic Plan'));

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
                    isExpired
                        ? (isArabic ? 'الاشتراك منتهي' : 'Subscription Expired')
                        : (isArabic ? 'الحالة: $planLabelText' : 'Status: $planLabelText'),
                    style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isExpired
                        ? (isArabic ? 'يرجى التجديد لتفعيل الحجز' : 'Renew to enable bookings')
                        : (isArabic ? 'المتبقي: $days يوم و $hours ساعة' : 'Remaining: $days d $hours h'),
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isExpired ? VSPColors.error.withValues(alpha: 0.12) : VSPColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(VSPRadius.xs),
            ),
            child: Text(
              isExpired ? (isArabic ? 'منتهي' : 'Expired') : (isArabic ? 'نشط' : 'Active'),
              style: TextStyle(
                color: isExpired ? VSPColors.error : VSPColors.accent,
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
