import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://mktqkddbcddrxjxabdua.supabase.co',
    'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE'
  );
  
  try {
    final response = await client.from('users').select().limit(1);
    if (response.isNotEmpty) {
      print('=== COLUMN DUMP ===');
      print(response.first.keys.toList());
    } else {
      print('=== TABLE IS EMPTY ===');
    }
  } catch (e) {
    print('Error: $e');
  }
}
