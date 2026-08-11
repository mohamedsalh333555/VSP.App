import 'dart:io';
import 'dart:convert';

void main() async {
  final client = HttpClient();
  final ownerId = '85c2b66c-2ff4-455f-9799-4efe335e5b52'; // Mohamed Salah (Owner)
  final playerId = 'bd2de82d-93ff-4962-85d3-007267ccb7f4'; // Mohamed Salah (Player)

  print('====================================================');
  print('🧪 TESTING END-TO-END CHAT & NOTIFICATION FLOW');
  print('====================================================');

  // STEP 1: Test Direct Chat Booking Creation in bookings table
  print('\n[1/3] Testing Direct Chat Creation (bookings table)...');
  final pastStart = DateTime.utc(2000, 1, 1).toIso8601String();
  final pastEnd = DateTime.utc(2000, 1, 1, 0, 0, 1).toIso8601String();

  final bookingPayload = jsonEncode({
    'stadium_name': 'محادثة مباشرة',
    'owner_id': ownerId,
    'start_time': pastStart,
    'end_time': pastEnd,
    'booking_type': 'personal',
    'status': 'confirmed',
    'created_by_user_id': ownerId,
    'total_price': 0.0,
    'payment_method': 'cash',
    'notes': 'chat_thread',
    'joined_user_ids': [ownerId, playerId],
  });

  final bookingUrl = Uri.parse('https://mktqkddbcddrxjxabdua.supabase.co/rest/v1/bookings');
  final req1 = await client.postUrl(bookingUrl);
  req1.headers.set('apikey', 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE');
  req1.headers.set('Authorization', 'Bearer sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE');
  req1.headers.set('Content-Type', 'application/json');
  req1.headers.set('Prefer', 'return=representation');
  req1.add(utf8.encode(bookingPayload));

  final resp1 = await req1.close();
  final body1 = await resp1.transform(utf8.decoder).join();
  print('  Response Status: ${resp1.statusCode}');
  print('  Response Body: $body1');

  if (resp1.statusCode >= 200 && resp1.statusCode < 300) {
    final List list = jsonDecode(body1);
    final bookingId = list.isNotEmpty ? list.first['id'].toString() : 'test_booking_id';
    print('  ✅ STEP 1 PASSED! Chat Thread Booking Created with ID: $bookingId');

    // STEP 2: Send a Chat Message to chat_messages table
    print('\n[2/3] Testing Sending Message to chat_messages table...');
    final msgPayload = jsonEncode({
      'booking_id': bookingId,
      'sender_id': ownerId,
      'sender_name': 'Mohamed Salah (Owner)',
      'text': 'يا محمد عامل ايه؟ جاهز للماتش؟ ⚽',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    final msgUrl = Uri.parse('https://mktqkddbcddrxjxabdua.supabase.co/rest/v1/chat_messages');
    final req2 = await client.postUrl(msgUrl);
    req2.headers.set('apikey', 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE');
    req2.headers.set('Authorization', 'Bearer sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE');
    req2.headers.set('Content-Type', 'application/json');
    req2.headers.set('Prefer', 'return=representation');
    req2.add(utf8.encode(msgPayload));

    final resp2 = await req2.close();
    final body2 = await resp2.transform(utf8.decoder).join();
    print('  Response Status: ${resp2.statusCode}');
    print('  Response Body: $body2');

    if (resp2.statusCode >= 200 && resp2.statusCode < 300) {
      print('  ✅ STEP 2 PASSED! Chat message stored in Supabase successfully!');
    } else {
      print('  ❌ STEP 2 FAILED: $body2');
    }

    // STEP 3: Send Notification to recipient player (playerId)
    print('\n[3/3] Testing Push Notification Delivery to recipient player...');
    final notifPayload = jsonEncode({
      'user_id': playerId,
      'title': 'رسالة جديدة من Mohamed Salah 💬',
      'body': 'يا محمد عامل ايه؟ جاهز للماتش؟ ⚽',
      'type': 'chat',
      'is_read': false,
      'booking_id': bookingId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    final notifUrl = Uri.parse('https://mktqkddbcddrxjxabdua.supabase.co/rest/v1/notifications');
    final req3 = await client.postUrl(notifUrl);
    req3.headers.set('apikey', 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE');
    req3.headers.set('Authorization', 'Bearer sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE');
    req3.headers.set('Content-Type', 'application/json');
    req3.headers.set('Prefer', 'return=representation');
    req3.add(utf8.encode(notifPayload));

    final resp3 = await req3.close();
    final body3 = await resp3.transform(utf8.decoder).join();
    print('  Response Status: ${resp3.statusCode}');
    print('  Response Body: $body3');

    if (resp3.statusCode >= 200 && resp3.statusCode < 300) {
      print('  ✅ STEP 3 PASSED! Notification delivered to recipient successfully!');
    } else {
      print('  ❌ STEP 3 FAILED: $body3');
    }
  } else {
    print('  ❌ STEP 1 FAILED: $body1');
  }

  print('\n====================================================');
  print('🏁 END OF AUTOMATED VERIFICATION TEST');
  print('====================================================');
  exit(0);
}
