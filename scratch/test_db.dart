import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://mktqkddbcddrxjxabdua.supabase.co',
    'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE'
  );
  
  try {
    final stadiumId = '02d86d70-741a-48a0-9968-b76ba6f9c191';
    print("--- UPDATING STADIUM $stadiumId IS_VERIFIED TO FALSE ---");
    final updateResult = await client
        .from('stadiums')
        .update({'is_verified': false})
        .eq('id', stadiumId)
        .select();
    
    print("Updated stadiums count: ${updateResult.length}");
    for (var s in updateResult) {
      print("Stadium ID: ${s['id']}, Name: ${s['name']}, is_verified: ${s['is_verified']}");
    }
  } catch (e) {
    print('Error updating DB: $e');
  }
}
