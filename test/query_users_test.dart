import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Query existing users', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    print('Initializing Supabase...');
    await Supabase.initialize(
      url: 'https://mktqkddbcddrxjxabdua.supabase.co',
      anonKey: 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE',
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
      ),
    );
    
    final client = Supabase.instance.client;
    print('Querying users table...');
    try {
      final response = await client.from('users').select('id, name, email, role, phone');
      print('USERS IN DATABASE: $response');
    } catch (e) {
      print('ERROR QUERYING USERS: $e');
    }
  });
}
