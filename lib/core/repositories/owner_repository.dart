import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../services/logger_service.dart';

class OwnerRepository {
 final SupabaseClient _supabase = Supabase.instance.client;

 OwnerRepository();

 Stream<List<Booking>> getOwnerBookings(String ownerId) {
 return _supabase
 .from('bookings')
 .stream(primaryKey: ['id'])
 .eq('owner_id', ownerId)
 .timeout(
 const Duration(seconds: 10),
 onTimeout: (sink) => sink.add([]),
 )
 .map((list) {
 final bookings = list
 .map((data) => Booking.fromFirestore(data, data['id'].toString()))
 .toList();
 bookings.sort((a, b) => b.startTime.compareTo(a.startTime));
 return bookings;
 })
 .handleError((e) {
 VSPLogger.w('Handled realtime error in owner getOwnerBookings: $e');
 });
 }

 Stream<List<Stadium>> getOwnerStadiums(String ownerId) {
 return _supabase
 .from('stadiums')
 .stream(primaryKey: ['id'])
 .eq('owner_id', ownerId)
 .timeout(
 const Duration(seconds: 10),
 onTimeout: (sink) => sink.add([]),
 )
 .map((list) => list
 .map((data) => Stadium.fromFirestore(data, data['id'].toString()))
 .toList())
 .handleError((e) {
 VSPLogger.w('Handled realtime error in getOwnerStadiums: $e');
 });
 }

  /// جلب الملخص المالي المحاسبي الشامل للمالك من الخادم (Zero-Trust Accounting)
  Future<Map<String, dynamic>> getOwnerFinancialSummary(String ownerId) async {
    try {
      final res = await _supabase.rpc('get_owner_financial_summary', params: {
        'p_owner_id': ownerId,
      });
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'success': false, 'available_balance': 0.0};
    } catch (e, stack) {
      VSPLogger.e('Error fetching financial summary for $ownerId', e, stack);
      return {'success': false, 'available_balance': 0.0};
    }
  }

  /// حساب صافي أرباح المالك من الحجوزات الإلكترونية بعد خصم رسوم المنصة
  Future<double> calculateOwnerRevenue(String ownerId) async {
    try {
      final summary = await getOwnerFinancialSummary(ownerId);
      if (summary['success'] == true && summary['net_online_earnings'] != null) {
        return (summary['net_online_earnings'] as num).toDouble();
      }

      // Fallback: حساب احتياطي مؤمّن ومخصوم منه الرسوم للحجوزات الإلكترونية
      final response = await _supabase
          .from('bookings')
          .select('total_price, platform_fee')
          .eq('owner_id', ownerId)
          .neq('payment_method', 'cash')
          .or('payment_status.eq.paid,is_paid.eq.true')
          .neq('status', 'cancelled');

      double total = 0;
      for (var row in (response as List)) {
        final price = (row['total_price'] ?? 0).toDouble();
        final fee = (row['platform_fee'] ?? 0).toDouble();
        total += (price - fee);
      }
      return total;
    } catch (e, stack) {
      VSPLogger.e('Error calculating owner revenue for $ownerId', e, stack);
      return 0.0;
    }
  }

 Future<double> calculateBookedHours(String ownerId) async {
 try {
 final response = await _supabase
 .from('bookings')
 .select('start_time, end_time, status')
 .eq('owner_id', ownerId)
 .neq('status', 'cancelled');

 double totalHours = 0.0;
 for (var row in (response as List)) {
 final start = DateTime.parse(row['start_time']);
 final end = DateTime.parse(row['end_time']);
 totalHours += end.difference(start).inMinutes / 60.0;
 }
 return totalHours;
 } catch (e, stack) {
 VSPLogger.e('Error calculating booked hours for $ownerId', e, stack);
 return 0.0;
 }
 }

 Stream<List<Map<String, dynamic>>> getTransactionsStream() {
 return _supabase
 .from('transactions')
 .stream(primaryKey: ['id'])
 .timeout(
 const Duration(seconds: 10),
 onTimeout: (sink) => sink.add([]),
 )
 .map((list) {
 final sorted = List<Map<String, dynamic>>.from(list);
 sorted.sort((a, b) {
 final dateA = DateTime.parse(a['created_at'].toString());
 final dateB = DateTime.parse(b['created_at'].toString());
 return dateB.compareTo(dateA);
 });
 return sorted;
 })
 .handleError((e) {
 VSPLogger.w('Handled realtime error in getTransactionsStream: $e');
 });
 }

 Future<List<Map<String, dynamic>>> getTransactionsList({int limit = 50}) async {
 try {
 final list = await _supabase
 .from('transactions')
 .select()
 .order('created_at', ascending: false)
 .limit(limit);
 return List<Map<String, dynamic>>.from(list);
 } catch (e, stack) {
 VSPLogger.e('Error fetching transactions list', e, stack);
 return [];
 }
 }

 /// إرسال طلب تسوية وصرف مستحقات المالك إلكترونياً
 Future<Map<String, dynamic>> requestPayoutSettlement({
 required double amount,
 required String method,
 required String destination,
 }) async {
 try {
 final uid = _supabase.auth.currentUser?.id;
 if (uid == null) {
 return {'success': false, 'error': 'User not authenticated'};
 }

 final response = await _supabase.rpc('request_owner_payout_settlement_atomic', params: {
 'p_owner_id': uid,
 'p_amount': amount,
 'p_method': method,
 'p_destination': destination,
 });

 if (response is Map) {
 return Map<String, dynamic>.from(response);
 }
 return {'success': true};
 } catch (e, stack) {
 VSPLogger.e('Error requesting payout settlement', e, stack);
 return {'success': false, 'error': e.toString()};
 }
 }
}

