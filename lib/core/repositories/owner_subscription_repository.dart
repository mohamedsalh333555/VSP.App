import 'package:supabase_flutter/supabase_flutter.dart';

class OwnerSubscriptionRepository {
  final SupabaseClient _supabase;

  OwnerSubscriptionRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchPublicPlans() async {
    final response = await _supabase
        .from('public_subscription_plans')
        .select(
          'code,name_ar,name_en,description_ar,description_en,monthly_price,yearly_price,trial_days,max_stadiums,features,display_order',
        )
        .order('display_order');
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> fetchTrialState() async {
    final result = await _supabase.rpc('get_owner_trial_state');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> startProTrial() async {
    final result = await _supabase.rpc('start_owner_trial');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> createProOrder({
    required String billingPeriod,
  }) async {
    if (billingPeriod != 'monthly' && billingPeriod != 'annual') {
      throw ArgumentError.value(
        billingPeriod,
        'billingPeriod',
        'Only monthly or annual billing is supported.',
      );
    }
    final result = await _supabase.rpc(
      'create_owner_subscription_order',
      params: {
        'p_plan_code': 'pro',
        'p_billing_period': billingPeriod,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<String> createPaymobCheckout({
    required String subscriptionOrderId,
  }) async {
    final response = await _supabase.functions.invoke(
      'create_paymob_intention',
      body: {'subscription_order_id': subscriptionOrderId},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final checkoutUrl = data['checkout_url']?.toString().trim();
    final checkoutUri =
        checkoutUrl == null ? null : Uri.tryParse(checkoutUrl);
    if (checkoutUri == null ||
        checkoutUri.scheme != 'https' ||
        checkoutUri.host.isEmpty) {
      throw StateError('checkout_url_missing_or_unsafe');
    }
    return checkoutUri.toString();
  }
}
