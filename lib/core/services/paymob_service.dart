import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymobFeeBreakdown {
  const PaymobFeeBreakdown({
    required this.baseAmount,
    required this.vspFee,
    required this.gatewayFee,
    required this.totalFees,
    required this.totalAmount,
  });

  final double baseAmount;
  final double vspFee;
  final double gatewayFee;
  final double totalFees;
  final double totalAmount;
}

/// Client adapter around server-authoritative Paymob checkout.
/// Fee configuration is read from the central Supabase policy for display;
/// the payment Edge Function recalculates it server-side before charging.
class PaymobService {
  static Future<PaymobFeeBreakdown> getFeeBreakdown(double baseAmount) async {
    if (baseAmount <= 0) {
      throw ArgumentError.value(baseAmount, 'baseAmount', 'Must be greater than zero.');
    }

    final response = await Supabase.instance.client
        .from('platform_fee_config')
        .select('booking_vsp_rate,booking_paymob_rate,booking_paymob_fixed_fee')
        .eq('id', 1)
        .maybeSingle();

    if (response == null) {
      throw StateError('Authoritative payment fee configuration is unavailable.');
    }

    final vspRate = NumberFormatHelper.toDouble(response['booking_vsp_rate']);
    final gatewayRate = NumberFormatHelper.toDouble(response['booking_paymob_rate']);
    final fixedFee = NumberFormatHelper.toDouble(response['booking_paymob_fixed_fee']);

    final vspFee = _round2(baseAmount * vspRate);
    final gatewayFee = _round2((baseAmount * gatewayRate) + fixedFee);
    final totalFees = _round2(vspFee + gatewayFee);

    return PaymobFeeBreakdown(
      baseAmount: baseAmount,
      vspFee: vspFee,
      gatewayFee: gatewayFee,
      totalFees: totalFees,
      totalAmount: _round2(baseAmount + totalFees),
    );
  }

  static Future<String?> getCheckoutUrlFromServer({
    required double amountInEgp,
    required String bookingId,
    required String userEmail,
    required String userName,
    required String userPhone,
    String paymentMethod = 'card',
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
          'payment_method': paymentMethod,
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
        'status=${response.status}, response=${response.data}',
      );
      return null;
    } catch (e) {
      debugPrint('[PaymobService] Checkout request failed: $e');
      return null;
    }
  }

  static double _round2(double value) => double.parse(value.toStringAsFixed(2));
}

class NumberFormatHelper {
  static double toDouble(dynamic value) {
    final result = double.tryParse(value?.toString() ?? '');
    if (result == null) {
      throw StateError('Invalid numeric fee configuration.');
    }
    return result;
  }
}
