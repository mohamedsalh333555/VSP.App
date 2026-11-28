import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymobFeePolicy {
  final double vspRate;
  final double ownerVspRate;
  final double gatewayRate;
  final double foreignGatewayRate;
  final double fixedGatewayFee;
  final bool vspAppliesToCash;
  final bool paymobAppliesToElectronic;
  final String gatewayFeeMode;
  final String feeVersion;

  const PaymobFeePolicy({
    required this.vspRate,
    this.ownerVspRate = 0.05,
    required this.gatewayRate,
    this.foreignGatewayRate = 0.026,
    required this.fixedGatewayFee,
    required this.vspAppliesToCash,
    required this.paymobAppliesToElectronic,
    this.gatewayFeeMode = 'gross_up',
    this.feeVersion = 'v2026_11_paymob_24_26',
  });

  factory PaymobFeePolicy.fromMap(Map<String, dynamic> map) => PaymobFeePolicy(
    vspRate: ((map['player_vsp_rate'] ?? map['booking_vsp_rate']) as num?)?.toDouble() ?? 0.05,
    ownerVspRate: (map['owner_vsp_rate'] as num?)?.toDouble() ?? 0.05,
    gatewayRate: ((map['booking_paymob_local_rate'] ?? map['booking_paymob_rate']) as num?)?.toDouble() ?? 0.024,
    foreignGatewayRate: (map['booking_paymob_foreign_rate'] as num?)?.toDouble() ?? 0.026,
    fixedGatewayFee: (map['booking_paymob_fixed_fee'] as num?)?.toDouble() ?? 3.0,
    vspAppliesToCash: map['vsp_applies_to_cash'] == true,
    paymobAppliesToElectronic: map['paymob_applies_to_electronic'] == true,
    gatewayFeeMode: map['gateway_fee_mode']?.toString() ?? 'gross_up',
    feeVersion: map['fee_version']?.toString() ?? 'v2026_11_paymob_24_26',
  );

  int _toPiasters(double amount) => (amount * 100).round();
  double _fromPiasters(int piasters) => double.parse((piasters / 100.0).toStringAsFixed(2));

  double platformFee(double baseAmount) {
    if (baseAmount <= 0) return 0;
    final baseP = _toPiasters(baseAmount);
    return _fromPiasters((baseP * vspRate).round());
  }

  double ownerCommission(double baseAmount) {
    if (baseAmount <= 0) return 0;
    final baseP = _toPiasters(baseAmount);
    return _fromPiasters((baseP * ownerVspRate).round());
  }

  double ownerNet(double baseAmount) {
    if (baseAmount <= 0) return 0;
    final baseP = _toPiasters(baseAmount);
    final ownerFeeP = (baseP * ownerVspRate).round();
    return _fromPiasters((baseP - ownerFeeP).clamp(0, baseP));
  }

  double gatewayFee(double baseAmount, {bool isForeign = false}) {
    if (baseAmount <= 0 || !paymobAppliesToElectronic) return 0;
    if (gatewayFeeMode == 'convenience_fee_by_paymob') return 0;

    final baseP = _toPiasters(baseAmount);
    final playerVspP = (baseP * vspRate).round();
    final playerSubtotalP = baseP + playerVspP;
    final fixedP = _toPiasters(fixedGatewayFee);
    final rate = isForeign ? foreignGatewayRate : gatewayRate;

    if (gatewayFeeMode == 'gross_up') {
      final totalP = ((playerSubtotalP + fixedP) / (1.0 - rate)).round();
      return _fromPiasters((totalP - playerSubtotalP).clamp(0, totalP));
    }
    return _fromPiasters((playerSubtotalP * rate).round() + fixedP);
  }

  double serviceFee(double baseAmount, {bool isForeign = false}) =>
      double.parse((platformFee(baseAmount) + gatewayFee(baseAmount, isForeign: isForeign)).toStringAsFixed(2));

  double total(double baseAmount, {bool isForeign = false}) =>
      double.parse((baseAmount + serviceFee(baseAmount, isForeign: isForeign)).toStringAsFixed(2));
}

class PaymobService {
  static Future<PaymobFeePolicy?> fetchFeePolicy() async {
    try {
      final response = await Supabase.instance.client
          .from('platform_fee_config')
          .select('booking_vsp_rate,player_vsp_rate,owner_vsp_rate,booking_paymob_rate,booking_paymob_local_rate,booking_paymob_foreign_rate,booking_paymob_fixed_fee,vsp_applies_to_cash,paymob_applies_to_electronic,gateway_fee_mode,fee_version')
          .eq('id', 1)
          .maybeSingle();
      if (response == null) return null;
      return PaymobFeePolicy.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('[PaymobService] Fee policy unavailable: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchPricingPreview(
    double basePrice, {
    String channel = 'local_card',
  }) async {
    try {
      final res = await Supabase.instance.client.rpc(
        'calculate_booking_pricing_v2',
        params: {
          'p_base_price': basePrice,
          'p_channel': channel,
        },
      );
      if (res is Map<String, dynamic> && res['success'] == true) {
        return res;
      }
      return null;
    } catch (e) {
      debugPrint('[PaymobService] Pricing preview unavailable: $e');
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
    return const PaymobFeePolicy(
      vspRate: 0.05,
      gatewayRate: 0.024,
      fixedGatewayFee: 3.0,
      vspAppliesToCash: false,
      paymobAppliesToElectronic: true,
    ).platformFee(baseAmountEgp);
  }
  @Deprecated('Use fetchFeePolicy() for runtime fee display.')
  static double calculateGatewayShare(double baseAmountEgp) {
    if (baseAmountEgp <= 0) return 0;
    return const PaymobFeePolicy(
      vspRate: 0.05,
      gatewayRate: 0.024,
      fixedGatewayFee: 3.0,
      vspAppliesToCash: false,
      paymobAppliesToElectronic: true,
    ).gatewayFee(baseAmountEgp);
  }
  @Deprecated('Use fetchFeePolicy() for runtime fee display.')
  static double calculateServiceFee(double baseAmountEgp) =>
      double.parse((calculatePlatformShare(baseAmountEgp) + calculateGatewayShare(baseAmountEgp)).toStringAsFixed(2));
  @Deprecated('Use fetchFeePolicy() for runtime fee display.')
  static double calculateTotalAmount(double baseAmountEgp) =>
      double.parse((baseAmountEgp + calculateServiceFee(baseAmountEgp)).toStringAsFixed(2));
}
