import 'dart:io';
import 'dart:convert';

void main() async {
  print('Updating Mohamed Salah booking in Supabase DB via REST API...');
  
  // Use PATCH to update total_price to 100.0 and end_time to 15:30 UTC
  final url = Uri.parse('https://mktqkddbcddrxjxabdua.supabase.co/rest/v1/bookings?id=eq.b354fc3f-6ec5-407c-a056-238e57eb1ae1');
  final client = HttpClient();

  final req = await client.openUrl('PATCH', url);
  req.headers.set('apikey', 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE');
  req.headers.set('Authorization', 'Bearer sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE');
  req.headers.set('Content-Type', 'application/json');
  req.headers.set('Prefer', 'return=representation');

  final payload = jsonEncode({
    'end_time': '2026-08-11T15:30:00+00:00',
    'total_price': 100.0,
  });

  req.write(payload);
  final resp = await req.close();
  final body = await resp.transform(utf8.decoder).join();

  print('Status Code: ${resp.statusCode}');
  print('Response Body: $body');
  exit(0);
}
