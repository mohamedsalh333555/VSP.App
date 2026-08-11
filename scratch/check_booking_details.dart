import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/config/app_config.dart';

void main() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  final client = Supabase.instance.client;
  final res = await client.from('bookings').select('*').eq('id', '545979b2-0b39-4b20-b667-0c2092804422');
  print('Booking details: $res');
}
