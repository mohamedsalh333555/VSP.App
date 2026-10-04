import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart';
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
  bool _isPaying = false;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final userModel = context.watch<AuthProvider>().userModel;
    final isPro = userModel?.isProPlan == true;
    final isTrialActive = userModel?.isInActiveTrial == true;

    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(
          isArabic ? 'اشتراك المالك' : 'Owner Subscription',
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
          child: _buildCanonicalOfferCard(
            context,
            isArabic,
            isPro,
            isTrialActive,
          ),
        ),
      ),
    );
  }

  Widget _buildCanonicalOfferCard(
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
          color: VSPColors.proAccent.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'الباقة الاحترافية' : 'Pro Plan',
            style: const TextStyle(
              color: VSPColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'كل مزايا VSP للمالك في باقة واحدة.'
                : 'All VSP owner features in one plan.',
            style: const TextStyle(
              color: VSPColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? '1000 جنيه / شهر' : '1000 EGP / month',
            style: const TextStyle(
              color: VSPColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: VSPColors.divider, height: 1),
          const SizedBox(height: 14),
          ...[
            isArabic ? 'VSP Copilot وإحصاءات الملاعب الذكية' : 'VSP Copilot and smart stadium insights',
            isArabic ? 'تشغيل وإدارة حتى 3 ملاعب' : 'Operate up to 3 stadiums',
            isArabic ? 'إدارة الحجوزات النقدية والأونلاين' : 'Manage cash and online bookings',
            isArabic ? 'تقارير مالية وسجل حساب واضح' : 'Clear financial reports and ledger',
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
          const SizedBox(height: 16),
          if (isPro)
            Container(
              width: double.infinity,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(VSPRadius.sm),
                border: Border.all(
                  color: VSPColors.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                isArabic ? 'اشتراكك الحالي مفعّل' : 'Your subscription is active',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isPaying
                        ? null
                        : () => _startSubscriptionPayment(context, 'monthly', isArabic),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VSPColors.accent,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(46),
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
                            isArabic ? '1000 جنيه' : '1000 EGP',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_isPaying || isTrialActive)
                        ? null
                        : () => _startOwnerTrial(context, isArabic),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VSPColors.textPrimary,
                      backgroundColor: VSPColors.surfaceAlt,
                      side: const BorderSide(color: VSPColors.divider),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.sm),
                      ),
                    ),
                    child: Text(
                      isTrialActive
                          ? (isArabic ? 'التجربة مفعلة' : 'Trial active')
                          : (isArabic ? 'جرب 7 أيام' : 'Try 7 days'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: TextButton(
                onPressed: _isPaying ? null : () => Navigator.maybePop(context),
                style: TextButton.styleFrom(
                  foregroundColor: VSPColors.textSecondary,
                  backgroundColor: VSPColors.surfaceAlt,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VSPRadius.sm),
                  ),
                ),
                child: Text(
                  isArabic ? 'لاحقًا' : 'Later',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
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
      final result = await Supabase.instance.client.rpc('start_owner_trial');
      final data = Map<String, dynamic>.from(result as Map);
      if (data['success'] != true) throw Exception(data['error']?.toString() ?? 'trial_start_failed');
      await auth.refreshProfile();
      if (context.mounted) VSPFeedback.showSuccess(context, isArabic ? 'تم تفعيل تجربتك المجانية لمدة 7 أيام.' : 'Your 7-day free trial is now active.');
    } catch (_) {
      if (context.mounted) VSPFeedback.showError(context, isArabic ? 'تعذر تفعيل التجربة الآن. قد تكون استُخدمت من قبل.' : 'Unable to activate the trial. It may have already been used.');
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
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
            ? 'أكمل عملية الدفع. سيتم تفعيل الاشتراك بعد تأكيد العملية.'
            : 'Complete the payment. Your subscription will activate after confirmation.');
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
