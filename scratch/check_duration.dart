import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/config/app_config.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://mktqkddbcddrxjrabdua.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...', // We can query via Supabase Flutter client
  );
}
