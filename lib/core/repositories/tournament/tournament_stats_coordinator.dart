import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Coordinates tournament statistics, clean sheets calculation, and leaderboard standings.
class TournamentStatsCoordinator {
  final SupabaseClient? _client;

  TournamentStatsCoordinator({SupabaseClient? client}) : _client = client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// Get top scorers for a championship aggregated from match goal details.
  Future<List<Map<String, dynamic>>> getTopScorersForChampionship(
    String championshipId,
  ) async {
    try {
      final response = await _supabase
          .from('tournament_matches')
          .select('goal_details, home_team_name, away_team_name')
          .eq('championship_id', championshipId)
          .neq('goal_details', '[]')
          .eq('is_completed', true);

      final Map<String, Map<String, dynamic>> scorerStats = {};

      for (final matchData in (response as List)) {
        final rawGoals = matchData['goal_details'] as List?;
        if (rawGoals == null || rawGoals.isEmpty) continue;

        final homeTeamName =
            matchData['home_team_name']?.toString().trim() ?? '';
        final awayTeamName =
            matchData['away_team_name']?.toString().trim() ?? '';

        for (final item in rawGoals) {
          if (item is Map) {
            final bool isOwnGoal =
                item['is_own_goal'] == true || item['isOwnGoal'] == true;
            final playerName = item['player_name']?.toString().trim() ??
                item['playerName']?.toString().trim() ??
                '';

            if (isOwnGoal || playerName.isEmpty) continue;

            String teamName = item['team_name']?.toString().trim() ??
                item['teamName']?.toString().trim() ??
                item['team']?.toString().trim() ??
                '';
            if (teamName.isEmpty || teamName == 'فريق غير محدد') {
              teamName = homeTeamName.isNotEmpty
                  ? homeTeamName
                  : (awayTeamName.isNotEmpty ? awayTeamName : '');
            }

            final key = '$playerName@$teamName';
            if (!scorerStats.containsKey(key)) {
              scorerStats[key] = {
                'name': playerName,
                'team': teamName,
                'goals': 0,
                'isOwnGoalCategory': false,
              };
            }
            scorerStats[key]!['goals'] =
                (scorerStats[key]!['goals'] as int) + 1;
          }
        }
      }

      final list = scorerStats.values.toList();
      list.sort((a, b) => (b['goals'] as int).compareTo(a['goals'] as int));
      return list;
    } catch (e) {
      debugPrint('Error getting top scorers: $e');
      return [];
    }
  }

  /// Get clean sheet teams/goalkeepers for a championship directly from database match scores.
  Future<List<Map<String, dynamic>>> getCleanSheetsForChampionship(
    String championshipId,
  ) async {
    try {
      final response = await _supabase
          .from('tournament_matches')
          .select('home_score, away_score, home_team_name, away_team_name, status')
          .eq('championship_id', championshipId)
          .eq('status', 'completed');

      final Map<String, int> teamCleanSheets = {};

      for (final matchData in (response as List)) {
        final homeScore = matchData['home_score'] as int?;
        final awayScore = matchData['away_score'] as int?;
        final homeTeam = matchData['home_team_name']?.toString() ?? '';
        final awayTeam = matchData['away_team_name']?.toString() ?? '';

        if (homeScore != null && awayScore != null) {
          if (awayScore == 0 && homeTeam.isNotEmpty) {
            teamCleanSheets[homeTeam] = (teamCleanSheets[homeTeam] ?? 0) + 1;
          }
          if (homeScore == 0 && awayTeam.isNotEmpty) {
            teamCleanSheets[awayTeam] = (teamCleanSheets[awayTeam] ?? 0) + 1;
          }
        }
      }

      final list = teamCleanSheets.entries
          .map((e) => {
                'team': e.key,
                'clean_sheets': e.value,
              })
          .toList();

      list.sort(
        (a, b) => (b['clean_sheets'] as int).compareTo(a['clean_sheets'] as int),
      );
      return list;
    } catch (e) {
      debugPrint('Error getting clean sheets: $e');
      return [];
    }
  }

  /// Fetches tournament standings for a league or specific group via Supabase RPC.
  Future<List<Map<String, dynamic>>> getChampionshipStandings(
    String championshipId, {
    String? groupName,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_championship_standings',
        params: {
          'p_championship_id': championshipId,
          'p_group_name': groupName,
        },
      );
      return List<Map<String, dynamic>>.from(response as List? ?? []);
    } catch (e) {
      debugPrint('Error fetching standings: $e');
      return [];
    }
  }
}
