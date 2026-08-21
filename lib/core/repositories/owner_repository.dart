import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';

class OwnerRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  OwnerRepository({dynamic firestore});

  Stream<List<Booking>> getOwnerBookings(String ownerId) {
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('owner_id', ownerId)
        .map((list) {
          final bookings = list
              .map((data) => Booking.fromFirestore(data, data['id'].toString()))
              .toList();
          bookings.sort((a, b) => b.startTime.compareTo(a.startTime));
          return bookings;
        });
  }

  Stream<List<Stadium>> getOwnerStadiums(String ownerId) {
     return _supabase
        .from('stadiums')
        .stream(primaryKey: ['id'])
        .eq('owner_id', ownerId)
        .map((list) => list
            .map((data) => Stadium.fromFirestore(data, data['id'].toString()))
            .toList());
  }

  Future<double> calculateOwnerRevenue(String ownerId) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select('total_price')
          .eq('owner_id', ownerId)
          .eq('payment_status', 'paid');

      double total = 0;
      for (var row in (response as List)) {
        total += (row['total_price'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      return 0;
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
    } catch (e) {
      return 0.0;
    }
  }

  Stream<List<Map<String, dynamic>>> getTransactionsStream() {
    return _supabase
        .from('transactions')
        .stream(primaryKey: ['id'])
        .map((list) {
          final sorted = List<Map<String, dynamic>>.from(list);
          sorted.sort((a, b) {
            final dateA = DateTime.parse(a['created_at'].toString());
            final dateB = DateTime.parse(b['created_at'].toString());
            return dateB.compareTo(dateA);
          });
          return sorted;
        });
  }

  Future<List<Map<String, dynamic>>> getTransactionsList() async {
    try {
      final list = await _supabase
          .from('transactions')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(list);
    } catch (e) {
      return [];
    }
  }
}
