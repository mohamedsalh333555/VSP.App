import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';

class OwnerRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Support old constructor to avoid compile error in DatabaseService
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

  Future<int> calculateBookedHours(String ownerId) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select('start_time, end_time')
          .eq('owner_id', ownerId);

      int totalHours = 0;
      for (var row in (response as List)) {
        final start = DateTime.parse(row['start_time']);
        final end = DateTime.parse(row['end_time']);
        totalHours += end.difference(start).inHours;
      }
      return totalHours;
    } catch (e) {
      return 0;
    }
  }
}
