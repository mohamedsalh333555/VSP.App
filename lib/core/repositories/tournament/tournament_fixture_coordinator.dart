import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';
import 'tournament_draw_notifier.dart';
import 'tournament_group_advancer.dart';
import 'tournament_stats_coordinator.dart';

/// Coordinates fixture generation for Knockout, Round-Robin League, and Group stages,
/// as well as advancing group stage qualifiers into knockout brackets.
class TournamentFixtureCoordinator {
  final SupabaseClient? _client;
  final Future<List<Team>> Function(List<String> ids)? _getTeamsByIds;
  final TournamentStatsCoordinator? _statsCoordinator;
  final TournamentDrawNotifier? _drawNotifier;
  final TournamentGroupAdvancer? _groupAdvancer;

  TournamentFixtureCoordinator({
    SupabaseClient? client,
    Future<List<Team>> Function(List<String> ids)? getTeamsByIds,
    TournamentStatsCoordinator? statsCoordinator,
    TournamentDrawNotifier? drawNotifier,
    TournamentGroupAdvancer? groupAdvancer,
  })  : _client = client,
        _getTeamsByIds = getTeamsByIds,
        _statsCoordinator = statsCoordinator,
        _drawNotifier = drawNotifier,
        _groupAdvancer = groupAdvancer;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  TournamentStatsCoordinator get _statsCoord =>
      _statsCoordinator ?? TournamentStatsCoordinator(client: _client);
  TournamentDrawNotifier get _notifier =>
      _drawNotifier ??
      TournamentDrawNotifier(
        client: _client,
        getTeamsByIds: _getTeamsByIds,
      );
  TournamentGroupAdvancer get _advancer =>
      _groupAdvancer ??
      TournamentGroupAdvancer(
        client: _client,
        statsCoordinator: _statsCoord,
      );

  /// Generates knockout fixtures (supports BYE logic and power-of-two expansion).
  Future<void> generateFixtures(String championshipId) async {
    final rpcRes = await _supabase.rpc(
      'generate_tournament_bracket_atomic',
      params: {'p_championship_id': championshipId},
    );
    if (rpcRes is! Map || rpcRes['success'] != true) {
      throw Exception(
        rpcRes is Map
            ? (rpcRes['error'] ?? rpcRes['message'] ?? 'فشل توليد قرعة البطولة')
            : 'فشل توليد قرعة البطولة',
      );
    }
    await sendDrawNotifications(championshipId);
  }

  /// Generates round-robin league fixtures through the server-authoritative RPC.
  Future<void> generateLeagueFixtures(String championshipId) async {
    final rpcRes = await _supabase.rpc(
      'generate_regular_league_fixtures_atomic',
      params: {'p_championship_id': championshipId},
    );
    if (rpcRes is! Map || rpcRes['success'] != true) {
      throw Exception(
        rpcRes is Map
            ? (rpcRes['error'] ?? rpcRes['message'] ?? 'فشل توليد مباريات الدوري')
            : 'فشل توليد مباريات الدوري',
      );
    }
  }

  /// Generates group-stage fixtures through the server-authoritative RPC.
  Future<void> generateGroupsFixtures(String championshipId) async {
    final rpcRes = await _supabase.rpc(
      'generate_regular_group_fixtures_atomic',
      params: {'p_championship_id': championshipId},
    );
    if (rpcRes is! Map || rpcRes['success'] != true) {
      throw Exception(
        rpcRes is Map
            ? (rpcRes['error'] ?? rpcRes['message'] ?? 'فشل توليد مباريات المجموعات')
            : 'فشل توليد مباريات المجموعات',
      );
    }
  }

  /// Automatic qualification from group stages to knockout elimination bracket.
  Future<void> advanceGroupsToKnockout(String championshipId) =>
      _advancer.advanceGroupsToKnockout(championshipId);

  /// Sends draw notification to members of all teams in the championship.
  Future<void> sendDrawNotifications(String championshipId) =>
      _notifier.sendDrawNotifications(championshipId);
}
