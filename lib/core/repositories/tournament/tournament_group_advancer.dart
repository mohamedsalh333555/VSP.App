import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tournament_bracket_engine.dart';
import 'tournament_stats_coordinator.dart';

/// Coordinates advancing group stage qualifiers into knockout brackets.
class TournamentGroupAdvancer {
  final SupabaseClient? _client;
  final TournamentStatsCoordinator? _statsCoordinator;

  TournamentGroupAdvancer({
    SupabaseClient? client,
    TournamentStatsCoordinator? statsCoordinator,
  })  : _client = client,
        _statsCoordinator = statsCoordinator;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  TournamentStatsCoordinator get _statsCoord =>
      _statsCoordinator ?? TournamentStatsCoordinator(client: _client);

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