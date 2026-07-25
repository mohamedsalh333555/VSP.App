import 'package:supabase/supabase.dart';
import '../lib/core/config/app_config.dart';

void main() async {
  final client = SupabaseClient(AppConfig.supabaseUrl, AppConfig.supabaseAnonKey);
  try {
    final res = await client.from('users').select().eq('id', 'f64e7da9-6af7-47f2-9916-87cc7e6a1739').maybeSingle();
    print("Exact DB row for user f64e7da9-6af7-47f2-9916-87cc7e6a1739:");
    print(res);
  } catch (e) {
    print("Error querying user: $e");
  }
}
