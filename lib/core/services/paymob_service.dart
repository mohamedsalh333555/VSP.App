import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymobFeePolicy {
  final double vspRate;
  final double gatewayRate;
  final double fixedGatewayFee;
  final bool vspAppliesToCash;
  final bool paymobAppliesToElectronic;

  const PaymobFeePolicy({
    required this.vspRate,
    required this.gatewayRate,
    required this.fixedGatewayFee,
    required this.vspAppliesToCash,
    required this.paymobAppliesToElectronic,
  });

  factory PaymobFeePolicy.fromMap(Map<String, dynamic> map) => PaymobFeePolicy(
    vspRate: (map['booking_vsp_rate'] as num?)?.toDouble() ?? 0,
    gatewayRate: (map['booking_paymob_rate'] as num?)?.toDouble() ?? 0,
    fixedGatewayFee: (map['booking_paymob_fixed_fee'] as num?)?.toDouble() ?? 0,
    vspAppliesToCash: map['vsp_applies_to_cash'] == true,
    paymobAppliesToElectronic: map['paymob_applies_to_electronic'] == true,
  );

  double platformFee(double baseAmount) =>
      baseAmount <= 0 ? 0 : double.parse((baseAmount * vspRate).toStringAsFixed(2));

  double gatewayFee(double baseAmount) =>
      baseAmount <= 0 || !paymobAppliesToElectronic
          ? 0
          : double.parse((baseAmount * gatewayRate + fixedGatewayFee).toStringAsFixed(2));

  double serviceFee(double baseAmount) =>
      double.parse((platformFee(baseAmount) + gatewayFee(baseAmount)).toStringAsFixed(2));

  double total(double baseAmount) =>
      double.parse((baseAmount + serviceFee(baseAmount)).toStringAsFixed(2));
}

class PaymobService {
  static Future<PaymobFeePolicy?> fetchFeePolicy() async {
    try {
      final response = await Supabase.instance.client
          .from('platform_fee_config')
          .select('booking_vsp_rate,booking_paymob_rate,booking_paymob_fixed_fee,vsp_applies_to_cash,paymob_applies_to_electronic')
          .eq('id', 1)
          .maybeSingle();
      if (response == null) return null;
      return PaymobFeePolicy.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('[PaymobService] Fee policy unavailable: $e');
      return null;
    }
  }

  static Future<String?> getCheckoutUrlFromServer({
    required double amountInEgp,
    required String bookingId,
    required String userEmail,
    required String userName,
    required String userPhone,
    String? integrationId,
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
          'integration_id': integrationId,
        },
      );

      if (response.status == 200 && response.data is Map<String, dynamic>) {
        final checkoutUrl = (response.data as Map<String, dynamic>)['checkout_url'];
        if (checkoutUrl is String && checkoutUrl.isNotEmpty) return checkoutUrl;
      }
      return null;
    } catch (e) {
      debugPrint('[PaymobService] Checkout error: $e');
      return null;
    }
  }

  // Legacy test helpers; production UI reads the same policy row via fetchFeePolicy().
  @Deprecated('Use fetchFeePolicy() for runtime fee display.')
  static double calculatePlatformShare(double baseAmountEgp) {
    if (baseAmountEgp <= 0) return 0;
    return double.parse((baseAmountEgp * 0.02).toStringAsFixed(2));
  }
  @Deprecated('Use fetchFeePolicy() for runtime fee display.')
  static double calculateGatewayShare(double baseAmountEgp) {
    if (baseAmountEgp <= 0) return 0;
    return double.parse(((baseAmountEgp * 0.0275) + 3).toStringAsFixed(2));
  }
  @Deprecated('Use fetchFeePolicy() for runtime fee display.')
  static double calculateServiceFee(double baseAmountEgp) =>
      double.parse((calculatePlatformShare(baseAmountEgp) + calculateGatewayShare(baseAmountEgp)).toStringAsFixed(2));
  @Deprecated('Use fetchFeePolicy() for runtime fee display.')
  static double calculateTotalAmount(double baseAmountEgp) =>
      double.parse((baseAmountEgp + calculateServiceFee(baseAmountEgp)).toStringAsFixed(2));
}
