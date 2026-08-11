import 'dart:io';
import 'dart:convert';

void main() async {
  print('Fetching all bookings raw...');
  final url = Uri.parse(
    'https://mktqkddbcddrxjxabdua.supabase.co/rest/v1/bookings?select=id,start_time,end_time,status,payment_status,is_paid'
  );
  final client = HttpClient();
  final req = await client.getUrl(url);
  req.headers.set('apikey', 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE');
  req.headers.set('Authorization', 'Bearer sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE');
  final resp = await req.close();
  final body = await resp.transform(utf8.decoder).join();
  print('HTTP Status: ${resp.statusCode}');
  print('Raw: $body');
  exit(0);
}
