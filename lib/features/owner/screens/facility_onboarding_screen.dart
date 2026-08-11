import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';
import 'add_stadium_wizard.dart';
import 'owner_documentation_wizard.dart';
import 'subscription_plans_screen.dart';
import '../../../shared/widgets/stadium_card.dart';
import '../../../shared/widgets/primary_button.dart';

class FacilityOnboardingScreen extends StatefulWidget {
  const FacilityOnboardingScreen({super.key});

  @override
  State<FacilityOnboardingScreen> createState() => _FacilityOnboardingScreenState();
}

class _FacilityOnboardingScreenState extends State<FacilityOnboardingScreen> {
  /// يتحقق من الباقة ويفتح Wizard أو يعرض Bottom Sheet الترقية
  Future<void> _onAddAnotherStadium(
    BuildContext context,
    List<Stadium> stadiums,
    bool isAr,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;
    if (user == null) return;

    final int maxAllowed = user.maxStadiums;
    final int current = stadiums.length;

    // ✅ لو ما وصلش للحد المسموح → يدخل الـ Wizard مباشرة
    if (current < maxAllowed) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddStadiumWizard()),
      );
      return;
    }

    // 🔒 وصل للحد → نعرض Bottom Sheet الترقية
    if (!context.mounted) return;
    await _showUpgradeBottomSheet(context, isAr, user);
  }

  /// Bottom Sheet شرح الترقية مع زر الاشتراك والعودة التلقائية
  Future<void> _showUpgradeBottomSheet(
    BuildContext context,
    bool isAr,
    UserModel user,
  ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _UpgradeBottomSheet(isAr: isAr, user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.currentUser?.uid ?? '';
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      body: SafeArea(
        child: StreamBuilder<List<Stadium>>(
            stream: StadiumRepository().getOwnerStadiums(uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    isAr ? 'حدث خطأ في تحميل الملاعب' : 'Error loading stadiums',
                    style: const TextStyle(color: VSPColors.error),
                  ),
                );
              }
              final stadiums = snapshot.data ?? [];
              final hasStadiums = stadiums.isNotEmpty;

              if (!hasStadiums) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    children: [
                      const Spacer(),
                      Text(
                        isAr ? 'ستظهر جميع ملاعبك هنا.' : 'All your stadiums will appear here.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: VSPColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isAr ? 'أضف ملعبك الأول للبدء' : 'Add your first stadium to start',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: VSPColors.textSecondary, fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity, height: 56,
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddStadiumWizard()),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VSPColors.accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(VSPRadius.xl),
                            ),
                          ),
                          child: Text(
                            isAr ? 'إضافة ملعب' : 'Add stadium',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      isAr ? 'ملاعبك المضافة' : 'Your Stadiums',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: VSPColors.textPrimary, fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 📊 Goal Gradient Progress Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: VSPColors.surface,
                        borderRadius: BorderRadius.circular(VSPRadius.lg),
                        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Iconsax.chart_1_copy, color: VSPColors.accent, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    isAr ? 'تقدم إكتمال ملفك الرياضي' : 'Profile Completion',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: VSPColors.accent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  '65% 🔥',
                                  style: TextStyle(
                                    color: VSPColors.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: const LinearProgressIndicator(
                              value: 0.65,
                              minHeight: 6,
                              backgroundColor: VSPColors.surfaceAlt,
                              valueColor: AlwaysStoppedAnimation<Color>(VSPColors.accent),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isAr
                                ? 'أحسنت! قطعنا 65% من الإعداد. تابع رفع الوثائق لتصل لـ 100% وتفعل شارة المالك الموثوق 🌟'
                                : '65% complete! Finish uploading documents to reach 100% and earn your Verified Badge 🌟',
                            style: const TextStyle(
                              color: VSPColors.textSecondary,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 💡 ملاحظة المعاينة
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Iconsax.flash_1_copy, color: VSPColors.accent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isAr
                                  ? 'هكذا ستظهر ملاعبك وتفاصيلها أمام اللاعبين في التطبيق.'
                                  : 'This is how your stadiums will appear to players.',
                              style: const TextStyle(
                                color: VSPColors.accent, fontSize: 13, fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: stadiums.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return StadiumCard(
                          stadium: stadiums[index],
                          isOwnerView: false,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddStadiumWizard(stadiumId: stadiums[index].id),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity, height: 56,
                          child: ElevatedButton.icon(
                            // 🔒 Gate: Check subscription before allowing second stadium
                            onPressed: () => _onAddAnotherStadium(context, stadiums, isAr),
                            icon: const Icon(Iconsax.add_circle_copy, color: Colors.white),
                            label: Text(
                              isAr ? 'إضافة ملعب آخر' : 'Add another stadium',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VSPColors.surfaceAlt,
                              foregroundColor: Colors.white,
                              side: BorderSide(color: VSPColors.divider),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(VSPRadius.xl),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity, height: 56,
                          child: ElevatedButton(
                            onPressed: () async {
                              final uid = authProvider.currentUser?.uid;
                              final updatedAdditional = Map<String, dynamic>.from(
                                authProvider.userModel?.additionalData ?? {},
                              )..['isOnboardingConfirmed'] = true;

                              if (uid != null) {
                                try {
                                  await Supabase.instance.client.from('users').update({
                                    'has_stadium': true,
                                    'additional_data': updatedAdditional,
                                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                                  }).eq('id', uid);
                                } catch (_) {}
                              }
                              await authProvider.updateProfile({
                                'additionalData': updatedAdditional,
                              });
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const OwnerDocumentationWizard()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VSPColors.accent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(VSPRadius.xl),
                              ),
                            ),
                            child: Text(
                              isAr ? 'متابعة لرفع الوثائق' : 'Continue to Upload Docs',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            }),
      ),
    );
  }
}

// ────────────────────────────────────────────────
// 🔒 Bottom Sheet: Upgrade to Pro Required
// ────────────────────────────────────────────────
class _UpgradeBottomSheet extends StatelessWidget {
  final bool isAr;
  final UserModel user;
  const _UpgradeBottomSheet({required this.isAr, required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(VSPRadius.xl),
          topRight: Radius.circular(VSPRadius.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Handle Bar ───
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: VSPColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Icon ───
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.crown_copy, color: Colors.amber, size: 32),
          ),
          const SizedBox(height: 16),

          // ─── Title ───
          Text(
            isAr ? 'تحتاج ترقية للباقة الاحترافية' : 'Pro Plan Required',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
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
                ? 'فترتك التجريبية المجانية تتيح لك إضافة ملعب واحد فقط.\n\nلإضافة ملعب ثانٍ، تحتاج الاشتراك في الباقة الاحترافية (1000 ج.م / شهر).\n\nبعد الاشتراك ستُعاد تلقائياً لإكمال إضافة ملعبك الجديد دون فقدان أي بيانات.'
                : 'Your free trial allows 1 stadium only.\n\nTo add a second stadium, you need to upgrade to the Pro Plan (1000 EGP/month).\n\nAfter subscribing, you will be returned automatically to complete adding your new stadium — no data will be lost.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VSPColors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),

          // ─── What you get ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                _FeatureRow(
                  icon: Iconsax.building_copy,
                  text: isAr ? 'إضافة وتشغيل حتى 3 ملاعب مختلفة' : 'Operate up to 3 stadiums',
                ),
                const SizedBox(height: 8),
                _FeatureRow(
                  icon: Iconsax.chart_1_copy,
                  text: isAr ? 'تحليل توزيع الحجوزات بالساعة واليوم' : 'Hourly & daily booking analytics',
                ),
                const SizedBox(height: 8),
                _FeatureRow(
                  icon: Iconsax.headphones_copy,
                  text: isAr ? 'دعم فني وأولوية في تفعيل الحساب' : 'Priority owner support',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Subscribe Button ───
          PrimaryButton(
            text: isAr ? '👑  اشترك الآن في الباقة الاحترافية' : '👑  Upgrade to Pro Now',
            color: Colors.amber,
            textColor: Colors.black,
            onPressed: () async {
              // أغلق الـ Bottom Sheet أولاً
              Navigator.pop(context);
              // ثم افتح شاشة الباقات مع await (يرجع تلقائياً لما يرجع)
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()),
              );
              // بعد الرجوع: لو اشترك Pro الآن يقدر يضيف ملعب
              // الشاشة ستعيد البناء تلقائياً عبر Provider لأن UserModel تحدّث
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
    );
  }

  Widget _buildCurrentPlanBadge(bool isAr, UserModel user) {
    final bool isTrial = user.isInActiveTrial;
    final int daysRemaining = isTrial && user.effectiveTrialEndsAt != null
        ? user.effectiveTrialEndsAt!.difference(DateTime.now()).inDays.clamp(0, 999)
        : 0;

    final String planLabel = isTrial
        ? (isAr ? 'اشتراك مجاني — فترة تجريبية 3 شهور' : 'Free Trial — 3 Month Plan')
        : (isAr ? 'الباقة الأساسية (Basic)' : 'Basic Plan');

    final String daysText = isTrial
        ? (isAr ? 'متبقي $daysRemaining يوم من الفترة المجانية' : '$daysRemaining days remaining in free trial')
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
            color: VSPColors.accent, fontSize: 14, fontWeight: FontWeight.bold,
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