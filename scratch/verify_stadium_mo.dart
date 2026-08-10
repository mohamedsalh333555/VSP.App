import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://mktqkddbcddrxjxabdua.supabase.co',
    'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE',
  );

  try {
    print('Verifying stadium Mo in Supabase DB...');
    await client.from('stadiums').update({
      'is_verified': true,
      'is_blocked': false,
    }).eq('id', '6b1ab7e6-9513-4e2e-8768-f1350abe760e');

    print('SUCCESS: Set is_verified = true for stadium Mo!');
  } catch (e, stack) {
    print('Error verifying stadium: $e\n$stack');
  }
}
