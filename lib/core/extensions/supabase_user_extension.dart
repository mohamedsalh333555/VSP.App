import 'package:supabase_flutter/supabase_flutter.dart';

/// Extension to provide Firebase-compatible `uid` getter on Supabase [User].
extension SupabaseUserExtension on User {
  String get uid => id;
}
