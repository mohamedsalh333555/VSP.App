import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://mktqkddbcddrxjxabdua.supabase.co',
    'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE',
  );

  print('Testing Supabase query on bookings...');
  try {
    final res = await supabase.from('bookings').select('id, notes').limit(1);
    print('Query succeeded: $res');
  } catch (e) {
    print('Query failed: $e');
  }

  print('Testing insert into bookings...');
  try {
    final pastStart = DateTime.utc(2000, 1, 1).toIso8601String();
    final pastEnd = DateTime.utc(2000, 1, 1, 0, 0, 1).toIso8601String();
    final testMap = {
      'stadium_name': 'Direct Chat Test',
      'stadium_image_url': '',
      'owner_id': '85c2b66c-2ff4-455f-9799-4efe335e5b52',
      'start_time': pastStart,
      'end_time': pastEnd,
      'booking_type': 'personal',
      'notes': 'chat_thread',
      'status': 'confirmed',
      'created_by_user_id': '85c2b66c-2ff4-455f-9799-4efe335e5b52',
      'joined_user_ids': ['85c2b66c-2ff4-455f-9799-4efe335e5b52', '00000000-0000-0000-0000-000000000001'],
      'payment_method': 'cash',
      'total_price': 0.0,
      'max_players': 2,
      'current_players': 2,
      'is_paid': true,
      'payment_status': 'paid',
    };
    final inserted = await supabase.from('bookings').insert(testMap).select().single();
    print('Insert succeeded: $inserted');
  } on PostgrestException catch (e) {
    print('Insert failed with PostgrestException:');
    print('  Code: ${e.code}');
    print('  Message: ${e.message}');
    print('  Details: ${e.details}');
    print('  Hint: ${e.hint}');
  } catch (e) {
    print('Insert failed with generic error: $e');
  }
  exit(0);
}
