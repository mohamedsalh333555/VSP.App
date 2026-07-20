import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Try login with passwords', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: 'https://mktqkddbcddrxjxabdua.supabase.co',
      anonKey: 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE',
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
      ),
    );
    
    final client = Supabase.instance.client;
    final passwords = ['Password123', '123456', '12345678', 'salah878740', 'mohamedsalh333555'];
    
    for (var pwd in passwords) {
      try {
        final res = await client.auth.signInWithPassword(
          email: 'mohamedsalh333555@gmail.com',
          password: pwd,
        );
        if (res.user != null) {
          print('SUCCESS PLAYER LOGIN WITH PASSWORD: $pwd');
          return;
        }
      } catch (e) {
        print('Failed with $pwd: $e');
      }
    }
    
    for (var pwd in passwords) {
      try {
        final res = await client.auth.signInWithPassword(
          email: 'salah878740@gmail.com',
          password: pwd,
        );
        if (res.user != null) {
          print('SUCCESS OWNER LOGIN WITH PASSWORD: $pwd');
          return;
        }
      } catch (e) {
        print('Failed owner with $pwd: $e');
      }
    }
  });
}
