import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  try {
    final client = Supabase.instance.client;
    final res = await client.from('users').select().eq('id', 'f64e7da9-6af7-47f2-9916-87cc7e6a1739').maybeSingle();
    print("Exact DB row for user f64e7da9-6af7-47f2-9916-87cc7e6a1739:");
    print(res);
  } catch (e) {
    print("Error querying user: $e");
  }
}
