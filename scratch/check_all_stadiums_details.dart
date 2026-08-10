import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient(
    'https://mktqkddbcddrxjxabdua.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1rdHFrZGRiY2RkcnhqeGFiZHVhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDAzNzczNTYsImV4cCI6MjA1NTkzMzM1Nn0.74W4xIfl20w3b2N1_cQp59N59Z37n9c04R3tE-c1U0s',
  );

  final res = await client.from('stadiums').select();
  print('=== TOTAL STADIUMS COUNT: ${res.length} ===\n');

  for (int i = 0; i < res.length; i++) {
    final row = res[i];
    print('Stadium #${i + 1}:');
    print('  ID: ${row['id']}');
    print('  Name: ${row['name']}');
    print('  Owner ID: ${row['owner_id'] ?? row['ownerId']}');
    print('  Governorate: ${row['governorate']}');
    print('  Location: ${row['location']}');
    print('  isVerified (is_verified): ${row['is_verified'] ?? row['isVerified']}');
    print('  isApproved (is_approved): ${row['is_approved'] ?? row['isApproved']}');
    print('  Price per hour: ${row['price_per_hour'] ?? row['pricePerHour']}');
    print('  Full Raw Row Keys: ${row.keys.toList()}');
    print('----------------------------------------');
  }
}
