import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  if (apiKey.isEmpty) {
    print('Please pass --dart-define=SUPABASE_ANON_KEY=...');
    return;
  }
  final url = Uri.parse('https://mktqkddbcddrxjxabdua.supabase.co/rest/v1/stadiums?select=*');
  final response = await http.get(url, headers: {
    'apikey': apiKey,
    'Authorization': 'Bearer $apiKey',
  });

  if (response.statusCode == 200) {
    final List list = json.decode(response.body);
    print('=== TOTAL STADIUMS IN DB: ${list.length} ===\n');
    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      print('Stadium #${i + 1}:');
      print('  ID: ${item['id']}');
      print('  Name: ${item['name']}');
      print('  Owner ID: ${item['owner_id'] ?? item['ownerId']}');
      print('  Governorate: ${item['governorate']}');
      print('  Location: ${item['location']}');
      print('  is_verified: ${item['is_verified']}');
      print('  is_approved: ${item['is_approved']}');
      print('  created_at: ${item['created_at']}');
      print('----------------------------------------');
    }
  } else {
    print('Error: ${response.statusCode} - ${response.body}');
  }
}
