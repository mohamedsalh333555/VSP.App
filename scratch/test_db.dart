import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://mktqkddbcddrxjxabdua.supabase.co',
    'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE'
  );
  
  try {
    final response = await client.from('users').select('id, email, phone, name, created_at');
    print('TOTAL_USERS_COUNT: ${response.length}');
    for (var i = 0; i < response.length && i < 10; i++) {
      final r = response[i];
      print('User $i: email=${r['email']}, phone=${r['phone']}, name=${r['name']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
