import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';
import '../../utils/app_date_formatter.dart';
import '../team_repository.dart';
import 'tournament_stats_coordinator.dart';

/// Coordinates match results reporting, score updates, schedule conflict checks, and round batch scheduling.
class TournamentMatchCoordinator {
  final SupabaseClient? _client;
  final TeamRepository? _teamRepository;
  final Future<void> Function(String teamId)? _onChampionCrowned;

  TournamentMatchCoordinator({
    SupabaseClient? client,
    TeamRepository? teamRepository,
    Future<void> Function(String teamId)? onChampionCrowned,
  })  : _client = client,
        _teamRepository = teamRepository,
        _onChampionCrowned = onChampionCrowned;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  TeamRepository get _teamRepo => _teamRepository ?? TeamRepository();

  /// Updates score for a tournament match, advances winner to next bracket slot, or crowns champion if final.
  Future<void> updateTournamentMatchScore({
    required String matchId,
    required int homeScore,
    required int awayScore,
    int? homePenalties,
    int? awayPenalties,
    String? winnerId,
    String? winnerName,
    List<GoalItem> goalDetails = const [],
  }) async {
    try {
      final response = await _supabase
          .from('tournament_matches')
          .select()
          .eq('id', matchId)
          .maybeSingle();
      if (response == null) throw 'Match not found';

      final String? nextMatchId =
          response['next_match_id'] ?? response['nextMatchId'];
      final int matchIndex =
          response['match_index'] ?? response['matchIndex'] ?? 0;
      final String championshipId =
          response['championship_id'] ?? response['championshipId'] ?? '';
      final String? matchStage = response['stage']?.toString();
      final int matchRoundIndex = response['round_index'] ?? response['roundIndex'] ?? -1;

      // Automatically assign scheduled_time to current time if match wasn't pre-scheduled
      if (response['scheduled_time'] == null) {
        try {
          await _supabase.from('tournament_matches').update({
            'scheduled_time': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', matchId);
        } catch (_) {}
      }

      bool rpcHandled = false;
      try {
        final rpcRes = await _supabase.rpc(
          'record_match_result_and_advance_atomic',
          params: {
            'p_match_id': matchId,
            'p_home_score': homeScore,
            'p_away_score': awayScore,
            'p_home_penalties': homePenalties,
            'p_away_penalties': awayPenalties,
            'p_winner_id': winnerId,
            'p_winner_name': winnerName,
            'p_goal_details': goalDetails.map((g) => g.toMap()).toList(),
          },
        );
        if (rpcRes != null && rpcRes['success'] == true) {
          rpcHandled = true;
        }
      } catch (rpcErr) {
        debugPrint('record_match_result_and_advance_atomic fallback: $rpcErr');
      }

      if (!rpcHandled) {
        final updatePayload = <String, dynamic>{
          'home_score': homeScore,
          'away_score': awayScore,
          'winner_id': winnerId,
          'status': 'completed',
          'is_completed': true,
          'goal_details': goalDetails.map((g) => g.toMap()).toList(),
        };
        if (homePenalties != null) updatePayload['home_penalties'] = homePenalties;
        if (awayPenalties != null) updatePayload['away_penalties'] = awayPenalties;

        try {
          await _supabase
              .from('tournament_matches')
              .update(updatePayload)
              .eq('id', matchId);
        } catch (err) {
          final fallbackPayload = <String, dynamic>{
            'home_score': homeScore,
            'away_score': awayScore,
            'winner_id': winnerId,
            'status': 'completed',
            'is_completed': true,
          };
          if (homePenalties != null) fallbackPayload['home_penalties'] = homePenalties;
          if (awayPenalties != null) fallbackPayload['away_penalties'] = awayPenalties;

          await _supabase
              .from('tournament_matches')
              .update(fallbackPayload)
              .eq('id', matchId);
        }

        if (nextMatchId != null) {
          final String slotField = (matchIndex % 2 == 0) ? 'home' : 'away';

          if (winnerId != null) {
            await _supabase
                .from('tournament_matches')
                .update({
                  '${slotField}_team_id': winnerId,
                  '${slotField}_team_name': winnerName,
                })
                .eq('id', nextMatchId);
          }
        }
      }

      // ── Final Match Check: Crown the Champion ONLY when it is a true final match (not group or league) ──
      final bool isGroupStage = matchStage == 'group_stage' || matchRoundIndex == 99;
      final bool isLeagueStage = matchStage == 'league';

      if (nextMatchId == null && winnerId != null && !isGroupStage && !isLeagueStage) {
        final champRes = await _supabase
            .from('championships')
            .select('champion_team_id')
            .eq('id', championshipId)
            .maybeSingle();

        final existingChamp = champRes?['champion_team_id'];
        if (existingChamp != null && existingChamp.toString().isNotEmpty) {
          // Already crowned champion — prevent double crowning
          return;
        }

        try {
          await _supabase.rpc(
            'crown_tournament_champion_atomic',
            params: {
              'p_championship_id': championshipId,
              'p_champion_team_id': winnerId,
              'p_champion_team_name': winnerName ?? '',
            },
          );
        } catch (rpcErr) {
          debugPrint('crown_tournament_champion_atomic fallback: $rpcErr');
          await _supabase.from('championships').update({
            'status': 'completed',
            'champion_team_id': winnerId,
            'champion_team_name': winnerName,
          }).eq('id', championshipId);

          final team = await _teamRepo.getTeam(winnerId);
          if (team != null) {
            final badges = List<String>.from(team.unlockedBadges);
            if (!badges.contains('cup_winner')) {
              badges.add('cup_winner');
            }
            await _supabase.from('teams').update({
              'championships_won': team.championshipsWon + 1,
              'unlocked_badges': badges,
            }).eq('id', winnerId);
          }
        }

        // Trigger celebration callback if provided
        if (_onChampionCrowned != null) {
          await _onChampionCrowned(winnerId);
        }
      } else if (isLeagueStage) {
        // In a league, check if all fixtures have been completed to crown the table leader
        try {
          final pendingMatches = await _supabase
              .from('tournament_matches')
              .select('id')
              .eq('championship_id', championshipId)
              .eq('is_completed', false)
              .limit(1);

          if ((pendingMatches as List).isEmpty) {
            final statsCoord = TournamentStatsCoordinator(client: _client);
            final standings = await statsCoord.getChampionshipStandings(championshipId);
            if (standings.isNotEmpty) {
              final topTeam = standings.first;
              final topTeamId = topTeam['team_id']?.toString();
              final topTeamName = topTeam['team_name']?.toString() ?? '';
              if (topTeamId != null && topTeamId.isNotEmpty) {
                await _supabase.from('championships').update({
                  'status': 'completed',
                  'champion_team_id': topTeamId,
                  'champion_team_name': topTeamName,
                }).eq('id', championshipId);

                if (_onChampionCrowned != null) {
                  await _onChampionCrowned(topTeamId);
                }
              }
            }
          }
        } catch (leagueErr) {
          debugPrint('Error evaluating league completion: $leagueErr');
        }
      }
    } catch (e) {
      debugPrint('Error updating tournament match score: $e');
      rethrow;
    }
  }

  /// Update scheduled time for a single match.
  Future<void> updateMatchScheduledTime({
    required String matchId,
    required DateTime scheduledTime,
  }) async {
    try {
      await _supabase.from('tournament_matches').update({
        'scheduled_time': scheduledTime.toUtc().toIso8601String(),
      }).eq('id', matchId);
    } catch (e) {
      debugPrint('Error updating match scheduled time: $e');
      rethrow;
    }
  }

  /// Auto-schedule matches in a specific round across 1, 2, or 4 days.
  Future<bool> autoScheduleRoundMatches({
    required String championshipId,
    required int roundIndex,
    required List<TournamentMatch> matches,
    required DateTime startDate,
    required TimeOfDay startTime,
    required int daysCount,
    required int matchDurationMinutes,
  }) async {
    try {
      if (matches.isEmpty) return false;
      final int totalMatches = matches.length;
      final int matchesPerDay = (totalMatches / daysCount).ceil();

      for (int i = 0; i < totalMatches; i++) {
        final match = matches[i];
        final int dayOffset = i ~/ matchesPerDay;
        final int matchIndexInDay = i % matchesPerDay;

        final currentDay = startDate.add(Duration(days: dayOffset));
        final scheduledDateTime = DateTime(
          currentDay.year,
          currentDay.month,
          currentDay.day,
          startTime.hour,
          startTime.minute,
        ).add(Duration(minutes: matchIndexInDay * matchDurationMinutes));

        await updateMatchScheduledTime(
          matchId: match.id,
          scheduledTime: scheduledDateTime,
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error auto-scheduling round matches: $e');
      return false;
    }
  }

  /// Clear/reset all scheduled times for matches in a specific round.
  Future<bool> clearRoundMatchSchedules({
    required String championshipId,
    required int roundIndex,
    required List<TournamentMatch> matches,
  }) async {
    try {
      if (matches.isEmpty) return false;
      for (final match in matches) {
        await _supabase.from('tournament_matches').update({
          'scheduled_time': null,
        }).eq('id', match.id);
      }
      return true;
    } catch (e) {
      debugPrint('Error clearing round match schedules: $e');
      return false;
    }
  }

  /// Check for scheduling conflicts where the same team has overlapping matches.
  Future<String?> checkMatchScheduleConflict({
    required String championshipId,
    required String matchId,
    required String? homeTeamId,
    required String? awayTeamId,
    required DateTime scheduledTime,
    int matchDurationMinutes = 45,
  }) async {
    try {
      final matchesRes = await _supabase
          .from('tournament_matches')
          .select(
            'id, scheduled_time, home_team_id, away_team_id, home_team_name, away_team_name',
          )
          .eq('championship_id', championshipId)
          .neq('id', matchId)
          .not('scheduled_time', 'is', null);

      final newMatchStart = scheduledTime;
      final newMatchEnd =
          scheduledTime.add(Duration(minutes: matchDurationMinutes));

      for (var m in (matchesRes as List)) {
        final rawTime = m['scheduled_time']?.toString();
        if (rawTime == null) continue;
        final existingStart = DateTime.parse(rawTime).toLocal();
        final existingEnd =
            existingStart.add(Duration(minutes: matchDurationMinutes));

        final bool overlaps = newMatchStart.isBefore(existingEnd) &&
            newMatchEnd.isAfter(existingStart);
        if (overlaps) {
          final mHomeId = m['home_team_id']?.toString();
          final mAwayId = m['away_team_id']?.toString();

          if (homeTeamId != null &&
              (homeTeamId == mHomeId || homeTeamId == mAwayId)) {
            final tName = m['home_team_name'] ?? 'الفريق';
            return 'تعارض: فريق ($tName) لديه مباراة أخرى مجدولة في نفس التوقيت (${AppDateFormatter.formatTime(existingStart, 'ar')})!';
          }
          if (awayTeamId != null &&
              (awayTeamId == mHomeId || awayTeamId == mAwayId)) {
            final tName = m['away_team_name'] ?? 'الفريق';
            return 'تعارض: فريق ($tName) لديه مباراة أخرى مجدولة في نفس التوقيت (${AppDateFormatter.formatTime(existingStart, 'ar')})!';
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error checking match schedule conflict: $e');
      return null;
    }
  }
}
