import 'dart:io';
import 'dart:convert';

void main() async {
  print('Cleaning up test messages from chat_messages table...');
  final url = Uri.parse('https://mktqkddbcddrxjxabdua.supabase.co/rest/v1/chat_messages?text=ilike.*جاهز للماتش*');
  final client = HttpClient();

  final req = await client.deleteUrl(url);
  req.headers.set('apikey', 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE');
  req.headers.set('Authorization', 'Bearer sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE');

  final resp = await req.close();
  final body = await resp.transform(utf8.decoder).join();

  print('Status Code: ${resp.statusCode}');
  print('Response Body: $body');
  print('Cleanup completed!');
  exit(0);
}
