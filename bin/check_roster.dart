import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://mktqkddbcddrxjxabdua.supabase.co',
    'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE',
  );

  try {
    final rosters = await supabase.from('championship_rosters').select();
    print('DB ROSTERS RESULT: $rosters');
  } catch (e) {
    print('ERROR: $e');
  }
}
