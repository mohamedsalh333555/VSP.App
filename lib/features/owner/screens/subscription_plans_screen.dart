import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/utils/vsp_feedback.dart';

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

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isArabic ? 'باقات اشتراك المالكين' : 'Subscription Plans',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(VSPSpacing.md),
        child: Column(
          children: [
            // 1. ⏱️ كارت العداد التنازلي المباشر لانتهاء الباقة
            if (userModel != null) _buildCountdownHeader(userModel, isArabic),

            const SizedBox(height: 20),

            // 2. 💳 كارت الباقة الأساسية (500 ج.م - متضمنة التجربة المجانية)
            _buildPlanCard(
              title: isArabic ? 'الباقة الأساسية' : 'Basic Plan',
              priceText: isArabic ? '500 ج.م' : '500 EGP',
              periodText: isArabic ? 'شهرياً (مجاناً لأول 3 شهور)' : 'Monthly (Free 1st 3 months)',
              stadiumsCount: 1,
              badgeText: isArabic ? '3 شهور مجاناً' : '3 Months Free',
              badgeColor: VSPColors.accent,
              isCurrentPlan: userModel?.isInActiveTrial == true || (userModel?.subscriptionPlan == 'basic' && userModel?.hasActiveSubscription == true),
              features: [
                isArabic ? 'إضافة وتشغيل ملعب واحد (1)' : 'Operate 1 Stadium',
                isArabic ? 'استقبال الحجوزات النقدية والأونلاين' : 'Accept Cash & Online Bookings',
                isArabic ? 'تنبيهات إشعار فورية بالحجوزات' : 'Instant Booking Notifications',
                isArabic ? 'لوحة تحكم وتحصيل أرباح 100%' : '100% Direct Revenue Dashboard',
              ],
              onSelect: () => _contactAdminForUpgrade(context, 'Basic (500 EGP)', isArabic),
              isArabic: isArabic,
            ),

            const SizedBox(height: 16),

            // 3. 👑 كارت الباقة الاحترافية (1000 ج.م - المجمعات)
            _buildPlanCard(
              title: isArabic ? 'الباقة الاحترافية' : 'Pro Plan',
              priceText: isArabic ? '1000 ج.م' : '1000 EGP',
              periodText: isArabic ? 'شهرياً' : 'Monthly',
              stadiumsCount: 3,
              badgeText: isArabic ? 'للمجمعات والملاعب المزدوجة' : 'For Multi-Pitches',
              badgeColor: Colors.amber,
              isProBorder: true,
              isCurrentPlan: userModel?.isProPlan == true,
              features: [
                isArabic ? 'إضافة وتشغيل حتى 3 ملاعب مختلفة' : 'Operate up to 3 Stadiums',
                isArabic ? 'إمكانية إضافة ملعب إضافي (+200 ج.م/شهرياً)' : 'Extra Stadium Add-on (+200 EGP/mo)',
                isArabic ? 'تحليل توزيع الحجوزات بالساعة واليوم' : 'Hourly & Daily Booking Analytics',
                isArabic ? 'تقرير مصادر الحجز (مباشر مقابل تحديات)' : 'Booking Source Report (Direct vs Challenge)',
                isArabic ? 'دعم فني وتفعيل أولوية أجهزة المالك' : 'Priority Owner Support',
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

  /// ⏱️ كارت العداد التنازلي التفاعلي
  Widget _buildCountdownHeader(UserModel user, bool isArabic) {
    final bool isExpired = user.isPlanExpired;
    final bool isTrial = user.isInActiveTrial;

    final days = _remainingTime.inDays;
    final hours = _remainingTime.inHours % 24;
    final minutes = _remainingTime.inMinutes % 60;
    final seconds = _remainingTime.inSeconds % 60;

    final String planLabelText = isArabic 
        ? (isProOwnerLabel(user) ? 'الباقة الاحترافية' : (isTrial ? 'فترة تجريبية' : 'الباقة الأساسية'))
        : (user.subscriptionPlanLabel);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isExpired ? Colors.red.withValues(alpha: 0.12) : VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(
          color: isExpired ? Colors.redAccent : (isTrial ? VSPColors.accent : Colors.amber),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isExpired ? LucideIcons.timerOff : LucideIcons.timer,
                    color: isExpired ? Colors.redAccent : VSPColors.accent,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? 'حالة الاشتراك والمهلة:' : 'Subscription Status:',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isExpired ? Colors.red.withValues(alpha: 0.2) : VSPColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isExpired ? (isArabic ? 'منتهي' : 'Expired') : planLabelText,
                  style: TextStyle(
                    color: isExpired ? Colors.redAccent : VSPColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isExpired) ...[
            Text(
              isArabic 
                  ? 'انتهت فترة التجربة المجانية والاشتراك'
                  : 'Free trial and subscription period expired',
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              isArabic 
                  ? 'يرجى الاشتراك لتفعيل حجز ملعبك واستقبال طلبات اللاعبين.'
                  : 'Please subscribe to resume pitch bookings and player requests.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
            ),
          ] else ...[
            Text(
              isArabic ? 'الوقت المتبقي لانتهاء الفترة الحالية:' : 'Time remaining for current active period:',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeUnit(days.toString(), isArabic ? 'يوم' : 'Days'),
                _buildTimeSeparator(),
                _buildTimeUnit(hours.toString().padLeft(2, '0'), isArabic ? 'ساعة' : 'Hours'),
                _buildTimeSeparator(),
                _buildTimeUnit(minutes.toString().padLeft(2, '0'), isArabic ? 'دقيقة' : 'Mins'),
                _buildTimeSeparator(),
                _buildTimeUnit(seconds.toString().padLeft(2, '0'), isArabic ? 'ثانية' : 'Secs'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool isProOwnerLabel(UserModel user) => user.isProPlan;

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: VSPColors.surfaceAlt,
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: VSPColors.accent,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildTimeSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        ':',
        style: TextStyle(color: VSPColors.accent, fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String priceText,
    required String periodText,
    required int stadiumsCount,
    required String badgeText,
    required Color badgeColor,
    required List<String> features,
    required VoidCallback? onSelect,
    required bool isArabic,
    bool isCurrentPlan = false,
    bool isProBorder = false,
  }) {
    return VSPCard(
      padding: const EdgeInsets.all(20),
      margin: EdgeInsets.zero,
      border: isProBorder ? Border.all(color: Colors.amber, width: 2) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(priceText, style: TextStyle(color: isProBorder ? Colors.amber : VSPColors.accent, fontSize: 32, fontWeight: FontWeight.w900)),
              const SizedBox(width: 6),
              Expanded(child: Text('/ $periodText', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12))),
            ],
          ),
          const Divider(color: VSPColors.divider, height: 24),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(LucideIcons.check, color: isProBorder ? Colors.amber : VSPColors.accent, size: 16),
                    const SizedBox(width: 10),
                    Expanded(child: Text(f, style: const TextStyle(color: Colors.white, fontSize: 13))),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: isCurrentPlan
                ? Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: VSPColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.checkCircle2, color: VSPColors.accent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          isArabic ? 'باقتك الحالية المفعلة' : 'Current Active Plan',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                : PrimaryButton(
                    text: onSelect != null
                        ? (isArabic ? 'تجديد / ترقية الباقة' : 'Subscribe / Upgrade')
                        : (isArabic ? 'مفعلة مجاناً' : 'Free Active'),
                    color: isProBorder ? Colors.amber : VSPColors.accent,
                    textColor: Colors.black,
                    onPressed: onSelect,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _contactAdminForUpgrade(BuildContext context, String planName, bool isArabic) async {
    final Uri whatsappUri = Uri.parse('https://wa.me/201100229462?text=${Uri.encodeComponent(isArabic ? 'أهلاً إدارة VSP، يرغب مالك الملعب في الاشتراك / ترقية حسابه إلى باقة $planName.' : 'Hi VSP Admin, owner wants to subscribe / upgrade account to $planName plan.')}');
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          VSPFeedback.showSuccess(context, isArabic ? 'يرجى التواصل مع إدارة VSP لطلب الترقية.' : 'Please contact VSP support to request upgrade.');
        }
      }
    } catch (_) {
      if (context.mounted) {
        VSPFeedback.showSuccess(context, isArabic ? 'يرجى التواصل مع إدارة VSP لطلب الترقية.' : 'Please contact VSP support to request upgrade.');
      }
    }
  }
}
