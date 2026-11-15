import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps raw Supabase auth access in core instead of feature widgets.
///
/// Emits a non-sensitive invalidation tick for any auth state transition.
/// The caller must re-fetch scoped data; a tick never conveys identity.
abstract final class ChallengeReportAuthEvents {
  static Stream<int> get changes =>
      Supabase.instance.client.auth.onAuthStateChange.map((_) => 1);
}
