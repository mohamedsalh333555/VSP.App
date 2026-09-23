import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client-side adapter for server-authoritative Paymob checkout.
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
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : null;
        final checkoutUrl = data?['checkout_url'];
        if (checkoutUrl is String && checkoutUrl.isNotEmpty) {
          debugPrint('[PaymobService] Server-generated checkout URL received.');
          return checkoutUrl;
        }
      }

      debugPrint(
        '[PaymobService] create_paymob_intention failed: '
        'status=\${response.status}, response=\${response.data}',
      );
      return null;
    } catch (e) {
      debugPrint('[PaymobService] Checkout request failed: \$e');
      return null;
    }
  }
}
