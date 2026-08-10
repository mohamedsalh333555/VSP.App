import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://mktqkddbcddrxjxabdua.supabase.co',
    'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE',
  );

  try {
    print('Checking all stadiums in Supabase database...');
    final response = await client.from('stadiums').select();
    final list = response as List;
    print('Total Stadiums Count in Database: ${list.length}\n');

    for (int i = 0; i < list.length; i++) {
      final doc = list[i] as Map<String, dynamic>;
      print('=== Stadium #${i + 1} ===');
      print('ID: ${doc['id']}');
      print('Name: ${doc['name']}');
      print('Owner ID: ${doc['owner_id']}');
      print('image_url column: ${doc['image_url']}');
      print('images column: ${doc['images']}');
      if (doc['features'] is Map) {
        print('features.allImages: ${(doc['features'] as Map)['allImages']}');
      } else {
        print('features: ${doc['features']}');
      }
      print('----------------------------------------\n');
    }
  } catch (e, stack) {
    print('Error checking DB: $e\n$stack');
  }
}
