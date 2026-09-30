import 'package:supabase_flutter/supabase_flutter.dart';
import 'tournament_stats_coordinator.dart';

/// Coordinates advancing group stage qualifiers into knockout brackets.
class TournamentGroupAdvancer {
  final SupabaseClient? _client;

  TournamentGroupAdvancer({
    SupabaseClient? client,
    TournamentStatsCoordinator? statsCoordinator,
  })  : _client = client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// Automatic qualification from group stages to knockout elimination bracket.
  Future<void> advanceGroupsToKnockout(String championshipId) async {
    final rpcRes = await _supabase.rpc(
      'advance_groups_to_knockout_atomic',
      params: {'p_championship_id': championshipId},
    );
    if (rpcRes is! Map || rpcRes['success'] != true) {
      throw Exception(
        rpcRes is Map
            ? (rpcRes['error'] ?? rpcRes['message'] ?? 'فشل تأهيل فرق المجموعات')
            : 'فشل تأهيل فرق المجموعات',
      );
    }
  }
}