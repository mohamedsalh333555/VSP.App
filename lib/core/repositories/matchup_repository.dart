import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';

class MatchupRepository {
  final SupabaseClient? _customClient;

  MatchupRepository([this._customClient]);

  SupabaseClient get _supabase => _customClient ?? Supabase.instance.client;

  /// 1. توليد كود دعوة جديد للفريق (صالح لمدة ساعة ويُبطل أي كود سابق)
  Future<Map<String, dynamic>> generateTeamInviteCode(String teamId) async {
    try {
      final response = await _supabase.rpc('generate_team_invite_code', params: {
        'p_team_id': teamId,
      });
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('Error generating team invite code: $e');
      rethrow;
    }
  }

  /// 2. إضافة فريق للمواجهة عبر الكود
  Future<Map<String, dynamic>> addTeamToMatchupByCode({
    required String bookingId,
    required String inviteCode,
  }) async {
    try {
      final response = await _supabase.rpc('add_team_to_matchup_by_code', params: {
        'p_booking_id': bookingId,
        'p_invite_code': inviteCode.trim().toUpperCase(),
      });
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('Error adding team to matchup by code: $e');
      rethrow;
    }
  }

  /// 3. تأكيد المواجهة وتحديد النمط تلقائياً (ثنائية duo أو الفايز مستمر winner_stays)
  Future<Map<String, dynamic>> confirmMatchup(String bookingId) async {
    try {
      final response = await _supabase.rpc('confirm_matchup_atomic', params: {
        'p_booking_id': bookingId,
      });
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('Error confirming matchup: $e');
      rethrow;
    }
  }

  /// 4. تسجيل نتيجة مباراة ضمن المواجهة (خاص بكابتن الحجز فقط)
  Future<Map<String, dynamic>> recordMatchupResult({
    required String bookingId,
    required String teamAId,
    required String teamBId,
    required String outcome, // 'team_a_win', 'team_b_win', 'draw'
  }) async {
    try {
      final response = await _supabase.rpc('record_matchup_result_atomic', params: {
        'p_booking_id': bookingId,
        'p_team_a_id': teamAId,
        'p_team_b_id': teamBId,
        'p_outcome': outcome,
      });
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('Error recording matchup result: $e');
      rethrow;
    }
  }

  /// 5. إغلاق المواجهة
  Future<Map<String, dynamic>> closeMatchup(String bookingId) async {
    try {
      final response = await _supabase.rpc('close_matchup_atomic', params: {
        'p_booking_id': bookingId,
      });
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('Error closing matchup: $e');
      rethrow;
    }
  }

  /// جلب قائمة الفرق المشاركة في المواجهة
  Future<List<MatchupTeam>> getMatchupTeams(String bookingId) async {
    try {
      final response = await _supabase
          .from('matchup_teams')
          .select('*, teams(id, name, logo_url, captain_id)')
          .eq('booking_id', bookingId)
          .order('joined_at', ascending: true);

      return (response as List).map((row) => MatchupTeam.fromMap(row)).toList();
    } catch (e) {
      debugPrint('Error fetching matchup teams: $e');
      return [];
    }
  }

  /// جلب سجل مباريات المواجهة
  Future<List<MatchupResult>> getMatchupResults(String bookingId) async {
    try {
      final response = await _supabase
          .from('matchup_results')
          .select('*')
          .eq('booking_id', bookingId)
          .order('created_at', ascending: true);

      return (response as List).map((row) => MatchupResult.fromMap(row)).toList();
    } catch (e) {
      debugPrint('Error fetching matchup results: $e');
      return [];
    }
  }

  /// جلب سجل المواجهات المباشرة بين فريقين (Head to Head)
  Future<TeamHeadToHead?> getTeamHeadToHead(String teamAId, String teamBId) async {
    try {
      final firstTeam = teamAId.compareTo(teamBId) < 0 ? teamAId : teamBId;
      final secondTeam = teamAId.compareTo(teamBId) < 0 ? teamBId : teamAId;

      final response = await _supabase
          .from('team_head_to_head')
          .select('*')
          .eq('team_a_id', firstTeam)
          .eq('team_b_id', secondTeam)
          .maybeSingle();

      if (response == null) return null;
      return TeamHeadToHead.fromMap(response);
    } catch (e) {
      debugPrint('Error fetching team head to head: $e');
      return null;
    }
  }

  /// جلب كل سجلات المواجهات المباشرة لفريق معين
  Future<List<Map<String, dynamic>>> getAllHeadToHeadForTeam(String teamId) async {
    try {
      final response = await _supabase
          .from('team_head_to_head')
          .select('*, team_a:teams!team_head_to_head_team_a_id_fkey(id, name, logo_url), team_b:teams!team_head_to_head_team_b_id_fkey(id, name, logo_url)')
          .or('team_a_id.eq.$teamId,team_b_id.eq.$teamId');

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error fetching all head to head for team: $e');
      return [];
    }
  }

  /// حساب جدول الترتيب اللحظي (النقاط = 3 × الفوز + 1 × التعادل)
  List<MatchupStandingsItem> calculateStandings(
    List<MatchupTeam> teams,
    List<MatchupResult> results,
  ) {
    final Map<String, Map<String, int>> stats = {};

    for (final t in teams) {
      stats[t.teamId] = {
        'played': 0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
        'points': 0,
      };
    }

    for (final r in results) {
      if (!stats.containsKey(r.teamAId) || !stats.containsKey(r.teamBId)) continue;

      stats[r.teamAId]!['played'] = stats[r.teamAId]!['played']! + 1;
      stats[r.teamBId]!['played'] = stats[r.teamBId]!['played']! + 1;

      if (r.outcome == 'team_a_win') {
        stats[r.teamAId]!['wins'] = stats[r.teamAId]!['wins']! + 1;
        stats[r.teamAId]!['points'] = stats[r.teamAId]!['points']! + 3;
        stats[r.teamBId]!['losses'] = stats[r.teamBId]!['losses']! + 1;
      } else if (r.outcome == 'team_b_win') {
        stats[r.teamBId]!['wins'] = stats[r.teamBId]!['wins']! + 1;
        stats[r.teamBId]!['points'] = stats[r.teamBId]!['points']! + 3;
        stats[r.teamAId]!['losses'] = stats[r.teamAId]!['losses']! + 1;
      } else {
        // Draw
        stats[r.teamAId]!['draws'] = stats[r.teamAId]!['draws']! + 1;
        stats[r.teamAId]!['points'] = stats[r.teamAId]!['points']! + 1;
        stats[r.teamBId]!['draws'] = stats[r.teamBId]!['draws']! + 1;
        stats[r.teamBId]!['points'] = stats[r.teamBId]!['points']! + 1;
      }
    }

    final List<MatchupStandingsItem> standings = [];
    for (final t in teams) {
      final s = stats[t.teamId] ?? {'played': 0, 'wins': 0, 'draws': 0, 'losses': 0, 'points': 0};
      standings.add(MatchupStandingsItem(
        teamId: t.teamId,
        teamName: t.teamName,
        logoUrl: t.logoUrl,
        matchesPlayed: s['played']!,
        wins: s['wins']!,
        draws: s['draws']!,
        losses: s['losses']!,
        points: s['points']!,
      ));
    }

    // Sort descending by Points, then Wins, then Matches Played
    standings.sort((a, b) {
      if (b.points != a.points) return b.points.compareTo(a.points);
      if (b.wins != a.wins) return b.wins.compareTo(a.wins);
      return a.matchesPlayed.compareTo(b.matchesPlayed);
    });

    return standings;
  }
}
