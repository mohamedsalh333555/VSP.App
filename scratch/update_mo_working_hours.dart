import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient(
    'https://mktqkddbcddrxjxabdua.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1rdHFrZGRiY2RkcnhqeGFiZHVhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDAzNzczNTYsImV4cCI6MjA1NTkzMzM1Nn0.74W4xIfl20w3b2N1_cQp59N59Z37n9c04R3tE-c1U0s',
  );

  final res = await client.from('stadiums').select().eq('name', 'Mo');
  if (res.isNotEmpty) {
    final currentFeatures = Map<String, dynamic>.from(res[0]['features'] ?? {});
    currentFeatures['workingHours'] = {
      'start': '04:00 PM',
      'end': '03:00 AM',
    };

    await client.from('stadiums').update({
      'features': currentFeatures,
    }).eq('name', 'Mo');

    print('Successfully updated stadium Mo working hours to 04:00 PM - 03:00 AM!');
  }
}
