import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client adapter for the server-authoritative Paymob checkout flow.
///
/// Pricing and payment fees are calculated by the Supabase Edge Function from
/// public.platform_fee_config and verified booking/tournament data. The mobile
/// client intentionally does not duplicate that financial logic.
class PaymobService {
  static Future<String?> getCheckoutUrlFromServer({
    required double amountInEgp,
    required String bookingId,
    required String userEmail,
    required String userName,
    required String userPhone,
    bool isTournamentPayment = false,
    bool isFullPayment = false,
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create_paymob_intention',
        body: {
          'booking_id': bookingId,
          'is_tournament_payment': isTournamentPayment,
          'is_full_payment': isFullPayment,
          'amount_egp': amountInEgp,
          'user_email': userEmail,
          'user_name': userName,
          'user_phone': userPhone,
        },
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : null;

        final checkoutUrl = data?['checkout_url']?.toString();
        if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
          debugPrint('[PaymobService] Server-generated checkout URL received.');
          return checkoutUrl;
        }
      }

      debugPrint(
        '[PaymobService] create_paymob_intention failed: '
        'status=${response.status}, response=${response.data}',
      );
      return null;
    } catch (e, stack) {
      debugPrint('[PaymobService] getCheckoutUrlFromServer failed: $e');
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }
}
