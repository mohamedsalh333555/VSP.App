import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/config/app_env.dart';

void main() {
  test('Debug Owner Dashboard Math for Current Date', () async {
    final supabase = SupabaseClient(
      AppEnv.supabaseUrl,
      AppEnv.supabaseAnonKey,
    );

    print('🔍 Fetching all bookings for owner from Supabase...');
    final response = await supabase
        .from('bookings')
        .select()
        .order('start_time', ascending: false);

    final now = DateTime.now().toLocal();
    print('📅 Current Device Local Date: ${now.year}-${now.month}-${now.day} (Local Time: $now)');

    print('\n================ ALL BOOKINGS IN DATABASE ================');
    double totalPipeline = 0.0;
    double digitalVspBalance = 0.0;
    double pitchCashRevenue = 0.0;
    int countToday = 0;

    for (var row in response) {
      final startTimeStr = row['start_time'] ?? row['startTime'];
      if (startTimeStr == null) continue;
      final startTimeUtc = DateTime.parse(startTimeStr.toString());
      final startTimeLocal = startTimeUtc.toLocal();

      final bool isToday = startTimeLocal.year == now.year &&
          startTimeLocal.month == now.month &&
          startTimeLocal.day == now.day;

      final double totalPrice = (row['total_price'] ?? row['totalPrice'] ?? 0.0).toDouble();
      final double depositPaid = (row['deposit_paid'] ?? row['depositPaid'] ?? 0.0).toDouble();
      final String paymentMethod = (row['payment_method'] ?? row['paymentMethod'] ?? '').toString().toLowerCase().trim();
      final bool isPaid = (row['is_paid'] ?? row['is_paid']) == true;
      final String paymentStatus = (row['payment_status'] ?? row['paymentStatus'] ?? '').toString();
      final String name = (row['player_team_name'] ?? row['playerTeamName'] ?? row['host_name'] ?? '').toString();

      print('📌 ID: ${row['id']}');
      print('   Name: $name | Price: $totalPrice | Deposit: $depositPaid');
      print('   Method: "$paymentMethod" | Status: $paymentStatus | IsPaid: $isPaid');
      print('   Start UTC: $startTimeUtc -> Start Local: $startTimeLocal | IsToday: $isToday');
      print('----------------------------------------------------');

      if (isToday) {
        countToday++;
        totalPipeline += totalPrice;
        
        final bool isManual = (paymentMethod == 'cash' || (row['payment_transaction_id']?.toString().startsWith('MANUAL') == true));
        final bool isOnlinePayment = !isManual && (
          paymentMethod.contains('paymob') ||
          paymentMethod.contains('card') ||
          paymentMethod.contains('visa') ||
          paymentMethod.contains('mastercard') ||
          paymentMethod.contains('wallet') ||
          paymentMethod.contains('online') ||
          paymentMethod.contains('instapay') ||
          paymentMethod.contains('vodafone') ||
          isPaid == true ||
          paymentStatus == 'paid'
        );

        if (isOnlinePayment) {
          digitalVspBalance += totalPrice;
        } else {
          pitchCashRevenue += totalPrice;
        }
      }
    }

    print('\n📊 === SUMMARY FOR TODAY (${now.year}-${now.month}-${now.day}) ===');
    print('   Count Today: $countToday');
    print('   Total Pipeline (إجمالي الإيراد): $totalPipeline EGP');
    print('   Digital Balance (رقمي ⚡): $digitalVspBalance EGP');
    print('   Pitch Cash (دفع مباشر 💵): $pitchCashRevenue EGP');
  });
}
