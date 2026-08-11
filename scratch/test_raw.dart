import 'dart:io';
import 'dart:convert';

void main() async {
  final url = Uri.parse('https://mktqkddbcddrxjxabdua.supabase.co/rest/v1/bookings');
  final client = HttpClient();

  final pastStart = DateTime.utc(2000, 1, 1).toIso8601String();
  final pastEnd = DateTime.utc(2000, 1, 1, 0, 0, 1).toIso8601String();

  final payload = jsonEncode({
    'user_id': '85c2b66c-2ff4-455f-9799-4efe335e5b52',
    'stadium_name': 'محادثة مباشرة',
    'stadium_image_url': '',
    'owner_id': '85c2b66c-2ff4-455f-9799-4efe335e5b52',
    'start_time': pastStart,
    'end_time': pastEnd,
    'booking_type': 'personal',
    'notes': 'chat_thread',
    'status': 'confirmed',
    'created_by_user_id': '85c2b66c-2ff4-455f-9799-4efe335e5b52',
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
    'joined_user_ids': ['85c2b66c-2ff4-455f-9799-4efe335e5b52', 'bd2de82d-93ff-4962-85d3-007267ccb7f4'],
    'payment_method': 'cash',
    'total_price': 0.0,
    'max_players': 2,
    'current_players': 2,
    'is_paid': true,
    'payment_status': 'paid',
  });

  print('Sending POST request to bookings table...');
  final req = await client.postUrl(url);
  req.headers.set('apikey', 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE');
  req.headers.set('Authorization', 'Bearer sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE');
  req.headers.set('Content-Type', 'application/json');
  req.headers.set('Prefer', 'return=representation');
  req.add(utf8.encode(payload));

  final resp = await req.close();
  final body = await resp.transform(utf8.decoder).join();

  print('Status Code: ${resp.statusCode}');
  print('Response Body: $body');
}
