import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://mktqkddbcddrxjxabdua.supabase.co/rest/v1/championships?select=id,name,match_duration');
  final response = await http.get(
    url,
    headers: {
      'apikey': 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE',
      'Authorization': 'Bearer sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE',
    },
  );

  print('Status: ${response.statusCode}');
  print('Body: ${response.body}');
}
