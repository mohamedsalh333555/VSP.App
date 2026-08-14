import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://mktqkddbcddrxjxabdua.supabase.co',
    'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE',
  );

  print('🧹 Purging all stale pending unpaid bookings from Supabase...');
  try {
    final response = await supabase
        .from('bookings')
        .delete()
        .eq('status', 'pending')
        .eq('is_paid', false);
    print('✅ Successfully purged all stale pending bookings: $response');
  } catch (e) {
    print('❌ Error purging bookings: $e');
  }
}
