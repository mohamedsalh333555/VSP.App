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
  List<Map<String, dynamic>> _plans = [];
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
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

  Future<void> _startOwnerTrial(BuildContext context, bool isArabic) async {
    setState(() => _isPaying = true);
    try {
      final result = await Supabase.instance.client.rpc('start_owner_trial');
      final data = Map<String, dynamic>.from(result as Map);
      if (data['success'] != true) throw Exception(data['error']?.toString() ?? 'trial_start_failed');
      final auth = context.read<AuthProvider>();
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
