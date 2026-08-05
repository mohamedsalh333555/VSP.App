import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/utils/vsp_feedback.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
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
          isArabic ? 'باقات اشتراك المالكين' : 'Owner Subscription Plans',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(VSPSpacing.md),
        child: Column(
          children: [
            // Current Plan Header Banner
            if (userModel != null) _buildCurrentPlanBanner(userModel, isArabic),

            const SizedBox(height: 20),

            // Plan 1: Free Trial Banner Notice (Fixed copy: 1 stadium across all labels)
            _buildPlanCard(
              title: isArabic ? 'الفترة التجريبية' : 'Free Trial',
              priceText: isArabic ? 'مجاناً' : 'Free',
              periodText: isArabic ? 'أول 3 شهور لملعب واحد (1)' : 'First 3 months for 1 stadium',
              stadiumsCount: 1,
              badgeText: isArabic ? 'مفعلة تلقائياً' : 'Auto Active',
              badgeColor: VSPColors.accent,
              isCurrentPlan: userModel?.isInActiveTrial == true,
              features: [
                isArabic ? 'إضافة ملعب واحد (1)' : 'Add 1 Stadium',
                isArabic ? 'استقبال الحجوزات النقدية والأونلاين' : 'Accept Cash & Online Bookings',
                isArabic ? 'لوحة تحكم تحصيلات أساسية' : 'Basic Gross Revenue Dashboard',
              ],
              onSelect: null,
              isArabic: isArabic,
            ),

            const SizedBox(height: 16),

            // Plan 2: Basic (500 EGP)
            _buildPlanCard(
              title: isArabic ? 'الباقة الأساسية Basic' : 'Basic Plan',
              priceText: '500 ج.م',
              periodText: isArabic ? 'شهرياً' : 'Monthly',
              stadiumsCount: 1,
              badgeText: isArabic ? 'الأكثر اقتصاداً' : 'Most Economic',
              badgeColor: Colors.blue,
              isCurrentPlan: userModel?.subscriptionPlan == 'basic' && userModel?.hasActiveSubscription == true,
              features: [
                isArabic ? 'إضافة ملعب واحد (1)' : 'Add 1 Stadium',
                isArabic ? 'لوحة تحكم تحصيلات مبسطة' : 'Simplified Revenue Dashboard',
                isArabic ? 'تنبيهات فورية للحجوزات' : 'Instant Booking Notifications',
                isArabic ? 'دعم فني مخصص للمالكين' : 'Dedicated Owner Support',
              ],
              onSelect: () => _contactAdminForUpgrade(context, 'Basic (500 ج.م)', isArabic),
              isArabic: isArabic,
            ),

            const SizedBox(height: 16),

            // Plan 3: Pro (1000 EGP) - Rebalanced to 3 stadiums + Custom Add-on
            _buildPlanCard(
              title: isArabic ? 'الباقة الاحترافية Pro' : 'Pro Plan',
              priceText: '1000 ج.م',
              periodText: isArabic ? 'شهرياً' : 'Monthly',
              stadiumsCount: 3,
              badgeText: isArabic ? 'الخيار الأقوى للمجمعات' : 'Ultimate Choice',
              badgeColor: Colors.amber,
              isProBorder: true,
              isCurrentPlan: userModel?.isProPlan == true,
              features: [
                isArabic ? 'إضافة حتى 3 ملاعب مختلفة' : 'Add up to 3 Stadiums',
                isArabic ? 'إمكانية إضافة ملعب إضافي (+200 ج.م/شهرياً)' : 'Custom Stadium Add-on (+200 EGP/mo)',
                isArabic ? 'داش بورد كامل وشامل للتحليلات' : 'Full Smart Analytics Dashboard',
                isArabic ? 'تحليل وتعبئة الساعات الميتة تلقائياً' : 'Dead Hours Analytics & Automation',
                isArabic ? 'رسم بياني لمقارنة النمو شهرياً' : 'Monthly Growth & Revenue Comparison',
                isArabic ? 'تصدير التقارير المالية والضريبية PDF' : 'Export Financial PDF Reports',
              ],
              onSelect: () => _contactAdminForUpgrade(context, 'Pro (1000 ج.م)', isArabic),
              isArabic: isArabic,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlanBanner(userModel, bool isArabic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.award, color: VSPColors.accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'باقتك الحالية:' : 'Current Plan:',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  userModel.subscriptionPlanLabel,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${userModel.maxStadiums} ${isArabic ? "ملعب مسموح" : "Stadium Allowed"}',
              style: const TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
              Text('/ $periodText', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13)),
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
                        ? (isArabic ? 'ترقية وحجز الباقة' : 'Upgrade Plan')
                        : (isArabic ? 'مفعلة مجاناً' : 'Free Active'),
                    color: isProBorder ? Colors.amber : VSPColors.accent,
                    textColor: isProBorder ? Colors.black : Colors.black,
                    onPressed: onSelect,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _contactAdminForUpgrade(BuildContext context, String planName, bool isArabic) async {
    final Uri whatsappUri = Uri.parse('https://wa.me/201000000000?text=${Uri.encodeComponent('أهلاً إدارة VSP، يرغب مالك الملعب في ترقية حسابه إلى باقة $planName.')}');
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

