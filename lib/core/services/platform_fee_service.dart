import 'package:supabase_flutter/supabase_flutter.dart';

/// Authoritative booking-payment fee configuration.
///
/// The live value is stored in public.platform_fee_config. Client code may read
/// it for display, but the server remains authoritative when creating payment
/// intents and recording financial transactions.
class PlatformFeeConfig {
  final double vspRate;
  final double paymobRate;
  final double paymobLocalRate;
  final double paymobForeignRate;
  final double paymobWalletRate;
  final double paymobFixedFee;

  const PlatformFeeConfig({
    required this.vspRate,
    required this.paymobRate,
    required this.paymobLocalRate,
    required this.paymobForeignRate,
    required this.paymobWalletRate,
    required this.paymobFixedFee,
  });

  double gatewayRateFor(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'wallet':
        return paymobWalletRate;
      case 'foreign_card':
        return paymobForeignRate;
      default:
        return paymobLocalRate;
    }
  }

  double calculateVspFee(double baseAmount) =>
      _round2(baseAmount * vspRate);

  double calculateGatewayFee(double baseAmount, String paymentMethod) =>
      _round2(baseAmount * gatewayRateFor(paymentMethod) + paymobFixedFee);

  double calculateTotalFees(double baseAmount, String paymentMethod) =>
      _round2(
        calculateVspFee(baseAmount) +
        calculateGatewayFee(baseAmount, paymentMethod),
      );

  double calculateTotalAmount(double baseAmount, String paymentMethod) =>
      _round2(baseAmount + calculateTotalFees(baseAmount, paymentMethod));

  static double _round2(double value) =>
      double.parse(value.toStringAsFixed(2));

  factory PlatformFeeConfig.fromMap(Map<String, dynamic> row) {
    final paymobRate = (row['booking_paymob_rate'] as num?)?.toDouble() ?? 0;
    return PlatformFeeConfig(
      vspRate: (row['booking_vsp_rate'] as num?)?.toDouble() ?? 0,
      paymobRate: paymobRate,
      paymobLocalRate:
          (row['booking_paymob_local_rate'] as num?)?.toDouble() ?? paymobRate,
      paymobForeignRate:
          (row['booking_paymob_foreign_rate'] as num?)?.toDouble() ?? paymobRate,
      paymobWalletRate:
          (row['booking_paymob_wallet_rate'] as num?)?.toDouble() ?? paymobRate,
      paymobFixedFee:
          (row['booking_paymob_fixed_fee'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PlatformFeeService {
  final SupabaseClient? _client;

  PlatformFeeService({SupabaseClient? client}) : _client = client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<PlatformFeeConfig> getBookingFeeConfig() async {
    final row = await _supabase
        .from('platform_fee_config')
        .select(
          'booking_vsp_rate, booking_paymob_rate, '
          'booking_paymob_local_rate, booking_paymob_foreign_rate, '
          'booking_paymob_wallet_rate, booking_paymob_fixed_fee',
        )
        .eq('id', 1)
        .single();

    return PlatformFeeConfig.fromMap(Map<String, dynamic>.from(row));
  }
}
