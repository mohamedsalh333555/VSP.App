import 'package:supabase_flutter/supabase_flutter.dart';

class OwnerSubscriptionRepository {
  // Paid owner subscriptions are retired — all owner features are free and unlocked.
  OwnerSubscriptionRepository({SupabaseClient? client});

  Future<Map<String, dynamic>> startProTrial() async {
    throw UnsupportedError('Owner subscriptions have been retired.');
  }

  Future<Map<String, dynamic>> createProOrder({
    required String billingPeriod,
  }) async {
    throw UnsupportedError('Owner subscriptions have been retired.');
  }

  Future<String> createPaymobCheckout({
    required String subscriptionOrderId,
  }) async {
    throw UnsupportedError('Owner subscriptions have been retired.');
  }
}
