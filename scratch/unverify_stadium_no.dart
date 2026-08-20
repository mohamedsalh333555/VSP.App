import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  if (apiKey.isEmpty) {
    print('Please pass --dart-define=SUPABASE_ANON_KEY=...');
    return;
  }
  final url = Uri.parse('https://mktqkddbcddrxjxabdua.supabase.co/rest/v1/stadiums?name=eq.No');
  
  final response = await http.patch(
    url,
    headers: {
      'apikey': apiKey,
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    },
    body: json.encode({'is_verified': false}),
  );

  print('Response code: ${response.statusCode}');
  print('Response body: ${response.body}');
}
