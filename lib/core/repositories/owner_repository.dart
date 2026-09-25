import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../services/logger_service.dart';
import '../services/no_show_dispute_service.dart';

class OwnerRepository {
  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  OwnerRepository({SupabaseClient? client}) : _client = client;

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

  /// دخل المالك من الحجوزات الإلكترونية — كامل قيمة الحجز بدون خصم عمولة أو رسوم على المالك
  Future<double> calculateOwnerRevenue(String ownerId) async {
    try {
      final summary = await getOwnerFinancialSummary(ownerId);
      if (summary['success'] == true) {
        final value = summary['owner_online_earnings'] ?? summary['net_online_earnings'];
        if (value is num) return value.toDouble();
      }
      // لا نحسب رقماً بديلاً من bookings إذا فشل المصدر المحاسبي؛ عرض رقم غير مؤكد مالياً أخطر من عرض خطأ.
      VSPLogger.w('Authoritative owner financial summary unavailable; refusing fallback revenue calculation.');
      return 0.0;
    } catch (e, stack) {
      VSPLogger.e('Error calculating owner revenue for $ownerId', e, stack);
      return 0.0;
    }
  }
