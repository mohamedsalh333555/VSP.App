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
    try {
      final champDoc = await _supabase
          .from('championships')
          .select()
          .eq('id', championshipId)
          .maybeSingle();
      if (champDoc == null) return;

      final int numGroups = int.tryParse(
            (champDoc['number_of_groups'] ?? champDoc['numberOfGroups'] ?? 2)
                .toString(),
          ) ??
          2;
      final int qualifyingPerGroup = int.tryParse(
            (champDoc['qualifying_per_group'] ??
                    champDoc['qualifyingPerGroup'] ??
                    2)
                .toString(),
          ) ??
          2;
      final List<String> groupNames = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

      // Map to store qualified teams per group in rank order
      final Map<String, List<Map<String, String>>> groupQualifiersMap = {};
      for (int g = 0; g < numGroups; g++) {
        final groupName = groupNames[g];
        final standings = await _statsCoord.getChampionshipStandings(
          championshipId,
          groupName: groupName,
        );

        final groupList = <Map<String, String>>[];
        for (int i = 0; i < min(qualifyingPerGroup, standings.length); i++) {
          final row = standings[i];
          groupList.add({
            'id': row['team_id'].toString(),
            'name': row['team_name'].toString(),
            'group': groupName,
          });
        }
        groupQualifiersMap[groupName] = groupList;
      }

      List<Map<String, String>> qualifiedTeams = [];

      if (numGroups >= 2 && qualifyingPerGroup >= 2) {
        for (int g = 0; g < numGroups; g += 2) {
          if (g + 1 < numGroups) {
            final g1 = groupNames[g];
            final g2 = groupNames[g + 1];

            final g1List = groupQualifiersMap[g1] ?? [];
            final g2List = groupQualifiersMap[g2] ?? [];

            final g1_1st = g1List.isNotEmpty ? g1List[0] : null;
            final g1_2nd = g1List.length > 1 ? g1List[1] : null;
            final g2_1st = g2List.isNotEmpty ? g2List[0] : null;
            final g2_2nd = g2List.length > 1 ? g2List[1] : null;

            if (g1_1st != null) qualifiedTeams.add(g1_1st);
            if (g2_2nd != null) qualifiedTeams.add(g2_2nd);

            if (g2_1st != null) qualifiedTeams.add(g2_1st);
            if (g1_2nd != null) qualifiedTeams.add(g1_2nd);
          } else {
            final g1 = groupNames[g];
            final g1List = groupQualifiersMap[g1] ?? [];
            qualifiedTeams.addAll(g1List);
          }
        }
      } else {
        groupQualifiersMap.values.forEach(qualifiedTeams.addAll);
      }

      if (qualifiedTeams.isEmpty) throw Exception('لا يوجد فرق متأهلة');

      // Delegate Groups to Knockout seeding computation to the pure engine
      final knockoutMatches =
          TournamentBracketEngine.buildKnockoutFromQualifiedTeams(
        championshipId: championshipId,
        qualifiedTeams: qualifiedTeams,
      );

      if (knockoutMatches.isNotEmpty) {
        await _supabase.from('tournament_matches').insert(knockoutMatches);
      }

      debugPrint(
        'Successfully advanced group winners to Knockout stage!',
      );
    } catch (e) {
      debugPrint('Error advancing groups to knockout: $e');
      rethrow;
    }
  }
}
