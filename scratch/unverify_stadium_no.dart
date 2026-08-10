import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1rdHFrZGRiY2RkcnhqeGFiZHVhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDAzNzczNTYsImV4cCI6MjA1NTkzMzM1Nn0.74W4xIfl20w3b2N1_cQp59N59Z37n9c04R3tE-c1U0s';
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
