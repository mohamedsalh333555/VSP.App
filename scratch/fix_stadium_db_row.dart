import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://mktqkddbcddrxjxabdua.supabase.co',
    'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE',
  );

  try {
    print('Updating images column for stadium Mo...');
    final images = [
      'https://mktqkddbcddrxjxabdua.supabase.co/storage/v1/object/public/stadium-images/stadiums/images/std_1786354201769.jpg',
      'https://mktqkddbcddrxjxabdua.supabase.co/storage/v1/object/public/stadium-images/stadiums/images/std_1786354208691.jpg'
    ];

    await client.from('stadiums').update({
      'images': images,
    }).eq('id', '6b1ab7e6-9513-4e2e-8768-f1350abe760e');

    print('SUCCESS: Updated stadium Mo with all 2 uploaded images!');
  } catch (e, stack) {
    print('Error updating stadium row: $e\n$stack');
  }
}
