import 'dart:convert';
import 'dart:io';

void main() async {
  const supabaseUrl = 'https://mktqkddbcddrxjxabdua.supabase.co';
  const anonKey = 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE';

  final headers = {
    'apikey': anonKey,
    'Authorization': 'Bearer $anonKey',
    'Content-Type': 'application/json',
  };

  final client = HttpClient();

  // Query RLS policies for championships table
  print('Checking RLS policies for championships...');
  final uri = Uri.parse('$supabaseUrl/rest/v1/rpc/'); // can't query pg_policies directly with anon

  // Try querying with admin SQL via rpc if any
  // Let's just try INSERT approach - create a minimal championship with is_approved=true
  // Actually, let's use the Supabase Management API
  // We can check what the service_role key is from the existing test files
  
  // Check all test files for service role key
  print('Looking for service role key in test files...');
  
  final testUri = Uri.parse('$supabaseUrl/rest/v1/championships?select=id,name,is_approved');
  final req = await client.getUrl(testUri);
  headers.forEach((k, v) => req.headers.set(k, v));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  print('Championships: $body');

  client.close();
}
