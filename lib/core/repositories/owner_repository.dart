import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../services/logger_service.dart';

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
      if (summary['success'] == true && summary['owner_online_earnings'] != null) {
        return (summary['owner_online_earnings'] as num).toDouble();
      }
      if (summary['success'] == true && summary['net_online_earnings'] != null) {
        // Backward compatibility: server now returns this field at gross owner value.
        return (summary['net_online_earnings'] as num).toDouble();
      }

      VSPLogger.w('Authoritative owner financial summary unavailable; refusing fallback revenue calculation.');
      return 0.0;
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
 final uid = _supabase.auth.currentUser?.id;
 if (uid == null) return Stream.value(const <Map<String, dynamic>>[]);
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
 final uid = _supabase.auth.currentUser?.id;
 if (uid == null) return [];
 final list = await _supabase
 .from('transactions')
 .select()
 .eq('user_id', uid)
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

  /// تأكيد استلام الدفع النقدي في الملعب ذرياً
  Future<dynamic> confirmCashBookingAtomic({
    required String bookingId,
    required String ownerId,
    required double totalPrice,
  }) async {
    return _supabase.rpc('confirm_cash_booking_atomic', params: {
      'p_booking_id': bookingId,
      'p_owner_id': ownerId,
      'p_total_price': totalPrice,
    });
  }

  /// تمديد وقت انتهاء الحجز/المباراة الجارية
  Future<void> extendBookingEndTime({
    required String bookingId,
    required DateTime newEndTime,
  }) async {
    final booking = await _supabase.from('bookings').select('end_time').eq('id', bookingId).single();
    final currentEnd = DateTime.parse(booking['end_time'].toString());
    final minutes = newEndTime.difference(currentEnd).inMinutes;
    if (minutes <= 0) throw Exception('New end time must be later than current end time');
    await extendOngoingMatchAtomic(bookingId: bookingId, addedMinutes: minutes);
  }

  /// تمديد وقت انتهاء المباراة الجارية ذرياً مع فحص التضارب
  Future<dynamic> extendOngoingMatchAtomic({
    required String bookingId,
    int addedMinutes = 30,
  }) async {
    return _supabase.rpc('owner_extend_match_atomic', params: {
      'p_booking_id': bookingId,
      'p_added_minutes': addedMinutes,
    });
  }

  /// إنشاء حجز يدوي ذرياً بواسطة المالك
  Future<dynamic> createManualBookingAtomic({
    required String ownerId,
    required String stadiumId,
    required DateTime startTime,
    required DateTime endTime,
    required String customerName,
    String? customerPhone,
    String? notes,
    required double totalPrice,
    required double collectedAmount,
    required int playerCount,
  }) async {
    return _supabase.rpc('owner_create_manual_booking_atomic', params: {
      'p_owner_id': ownerId,
      'p_stadium_id': stadiumId,
      'p_start_time': startTime.toUtc().toIso8601String(),
      'p_end_time': endTime.toUtc().toIso8601String(),
      'p_customer_name': customerName,
      'p_customer_phone': customerPhone,
      'p_notes': notes,
      'p_total_price': totalPrice,
      'p_collected_amount': collectedAmount,
      'p_current_players': playerCount,
    });
  }

  /// تحديث بيانات الحجز اليدوي بواسطة المالك
  Future<void> updateBookingDetails(String bookingId, Map<String, dynamic> updateMap) async {
    final endTimeRaw = updateMap['end_time'];
    if (endTimeRaw == null) throw Exception('end_time is required');
    final response = await _supabase.rpc('owner_update_manual_booking_atomic', params: {
      'p_booking_id': bookingId,
      'p_end_time': DateTime.parse(endTimeRaw.toString()).toUtc().toIso8601String(),
      'p_customer_name': updateMap['player_team_name']?.toString() ?? updateMap['customer_name']?.toString() ?? '',
      'p_customer_phone': updateMap['player_phone']?.toString(),
      'p_notes': updateMap['notes']?.toString(),
      'p_current_players': (updateMap['current_players'] as num?)?.toInt() ?? 1,
      'p_collected_amount': (updateMap['deposit_paid'] as num?)?.toDouble() ?? 0.0,
    });
    if (response is Map && response['success'] == false) throw Exception(response['error']?.toString() ?? 'Failed to update booking');
  }

  /// إدراج حجز هاتفي يدوي بواسطة المالك
  Future<Map<String, dynamic>> insertManualPhoneBooking(Map<String, dynamic> bookingData) async {
    final response = await createManualBookingAtomic(
      ownerId: (_supabase.auth.currentUser?.id ?? bookingData['owner_id']).toString(),
      stadiumId: bookingData['stadium_id'].toString(),
      startTime: DateTime.parse(bookingData['start_time'].toString()),
      endTime: DateTime.parse(bookingData['end_time'].toString()),
      customerName: (bookingData['player_team_name'] ?? bookingData['host_name'] ?? bookingData['customer_name'] ?? 'حجز يدوي').toString(),
      customerPhone: bookingData['player_phone']?.toString(),
      notes: bookingData['notes']?.toString(),
      totalPrice: (bookingData['total_price'] as num?)?.toDouble() ?? 0,
      collectedAmount: (bookingData['deposit_paid'] as num?)?.toDouble() ?? 0,
      playerCount: (bookingData['current_players'] as num?)?.toInt() ?? 1,
    );
    return Map<String,dynamic>.from(response as Map);
  }

  /// إلغاء الحجز اليدوي ذرياً مع معالجة العربون في الدفتر المالي
  Future<dynamic> cancelManualBookingAtomic({
    required String bookingId,
    required String ownerId,
    required bool refundDeposit,
  }) async {
    return _supabase.rpc('owner_cancel_manual_booking_atomic', params: {
      'p_booking_id': bookingId,
      'p_owner_id': ownerId,
      'p_refund_deposit': refundDeposit,
    });
  }

  /// تسجيل عدم حضور اللاعب (No-Show) وتحديث حالة الحجز وسجل اللاعب
  Future<void> recordPlayerNoShow({
    required String bookingId,
    String? playerId,
    double? stadiumLat,
    double? stadiumLng,
  }) async {
    final ownerId = _supabase.auth.currentUser?.id;
    if (ownerId == null) throw Exception('User not authenticated');
    final response = await _supabase.rpc('owner_record_no_show_atomic', params: {
      'p_booking_id': bookingId,
      'p_owner_id': ownerId,
      'p_notes': 'Player no-show reported by stadium owner',
    });
    if (response is Map && response['success'] == false) throw Exception(response['error']?.toString() ?? 'Failed to record no-show');
  }
}
