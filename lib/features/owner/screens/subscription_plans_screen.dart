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
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // ── 1. شريط حالة الاشتراك الهادئ ──
            if (userModel != null) _buildCompactStatusHeader(userModel, isArabic),

            const SizedBox(height: 16),

            // ── 2. الباقة الأساسية (Basic Plan) ──
            _buildPlanCard(
              title: isArabic ? 'الباقة الأساسية' : 'Basic Plan',
              priceText: isArabic ? '500 ج.م' : '500 EGP',
              periodText: isArabic ? 'شهرياً' : 'Monthly',
              badgeText: isArabic ? 'أول شهرين مجاناً' : 'First 2 Months Free',
              badgeColor: VSPColors.accent,
              isHighlighted: false,
              isCurrentPlan: isTrialOrBasic,
              buttonText: isTrialOrBasic
                  ? (isArabic ? 'باقتك الحالية (فترة تجريبية)' : 'Current Plan (Free Trial)')
                  : (isArabic ? 'ابدأ مجاناً (أول شهرين)' : 'Start Free (1st 2 Months)'),
              features: [
                isArabic ? 'تشغيل وإدارة ملعب واحد فقط (1)' : 'Full operation for 1 stadium only',
                isArabic ? 'استقبال الحجوزات النقدية والأونلاين ومنع التضارب' : 'Accept Cash & Online bookings with conflict prevention',
                isArabic ? 'فترة تجريبية مجانية شهرين بالكامل لتقييم المنظومة' : 'Full 2-month free evaluation period',
                isArabic ? 'تنظيم وإدارة البطولات والكؤوس لجميع الفرق مجاناً' : 'Free Tournament creation & cup management',
              ],
              onSelect: () => _contactAdminForUpgrade(context, 'Basic (500 EGP)', isArabic),
              isArabic: isArabic,
            ),

            const SizedBox(height: 16),

            // ── 3. الباقة الاحترافية (Pro Plan) ──
            _buildPlanCard(
              title: isArabic ? 'الباقة الاحترافية' : 'Pro Plan',
              priceText: isArabic ? '1000 ج.م' : '1000 EGP',
              periodText: isArabic ? 'شهرياً' : 'Monthly',
              badgeText: isArabic ? 'الأكثر اختياراً' : 'Most Popular',
              badgeColor: VSPColors.accent,
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

            const SizedBox(height: 24),
          ],
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
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(
          color: isExpired ? Colors.redAccent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
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
                color: isExpired ? Colors.redAccent : VSPColors.accent,
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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
              color: isExpired ? Colors.redAccent.withValues(alpha: 0.12) : VSPColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isExpired ? (isArabic ? 'منتهي' : 'Expired') : (isArabic ? 'نشط' : 'Active'),
              style: TextStyle(
                color: isExpired ? Colors.redAccent : VSPColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// كارد الباقة الموحد المتوافق 100% مع نظام تصميم VSP (Design System VSP Tokens)
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
    const tajawal = 'Tajawal';
    const poppins = 'Poppins';
    const fontFallback = ['Tajawal', 'Poppins', 'sans-serif'];

    return Container(
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFF141912) : VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.card), // 24.0px كروت VSP الرسمية
        border: Border.all(
          color: isHighlighted
              ? VSPColors.accent.withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.08),
          width: isHighlighted ? 1.6 : 1.0,
        ),
        boxShadow: [
          if (isHighlighted)
            BoxShadow(
              color: VSPColors.accent.withValues(alpha: 0.14),
              blurRadius: 24,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Title & High-End Badge ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    fontFamily: tajawal,
                    fontFamilyFallback: fontFallback,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: isHighlighted ? VSPColors.accent : badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(VSPRadius.full), // كبسولة كاملة
                    border: Border.all(
                      color: isHighlighted
                          ? VSPColors.accent
                          : badgeColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      if (isHighlighted)
                        BoxShadow(
                          color: VSPColors.accent.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: isHighlighted ? Colors.black : badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      fontFamily: tajawal,
                      fontFamilyFallback: fontFallback,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Price Row with Refined Typography ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  priceText,
                  style: TextStyle(
                    color: isHighlighted ? Colors.white : VSPColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    fontFamily: poppins,
                    fontFamilyFallback: fontFallback,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/ $periodText',
                  style: const TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: tajawal,
                    fontFamilyFallback: fontFallback,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Divider(
              color: isHighlighted
                  ? VSPColors.accent.withValues(alpha: 0.15)
                  : VSPColors.divider,
              height: 1,
            ),
            const SizedBox(height: 16),

            // ── Features List (Glowing Icon Capsules) ──
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: VSPColors.accent.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Iconsax.tick_circle_copy,
                          color: VSPColors.accent,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          f,
                          style: const TextStyle(
                            color: VSPColors.textPrimary,
                            fontSize: 13,
                            height: 1.4,
                            fontFamily: tajawal,
                            fontFamilyFallback: fontFallback,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: 18),

            // ── CTA Button: Unified Stadium Radius (VSPRadius.button = Full) ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: isCurrentPlan
                  ? Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(VSPRadius.button), // Stadium
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            buttonText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              fontFamily: tajawal,
                              fontFamilyFallback: fontFallback,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ElevatedButton(
                      onPressed: onSelect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isHighlighted ? VSPColors.accent : Colors.white.withValues(alpha: 0.08),
                        foregroundColor: isHighlighted ? Colors.black : Colors.white,
                        elevation: isHighlighted ? 6 : 0,
                        shadowColor: isHighlighted
                            ? VSPColors.accent.withValues(alpha: 0.45)
                            : Colors.transparent,
                        shape: const StadiumBorder(), // زر بيضاوي موحد مع باقي أزرار التطبيق
                      ),
                      child: Text(
                        buttonText,
                        style: TextStyle(
                          color: isHighlighted ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          fontFamily: tajawal,
                          fontFamilyFallback: fontFallback,
                        ),
                      ),
                    ),
            ),
          ],
        ),
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
