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
    } catch (_) {
      debugPrint('Error generating team invite code (details redacted)');
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
    } catch (_) {
      debugPrint('Error adding team to matchup by code (details redacted)');
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
    } catch (_) {
      debugPrint('Error confirming matchup (details redacted)');
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
    } catch (_) {
      debugPrint('Error recording matchup result (details redacted)');
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
    } catch (_) {
      debugPrint('Error closing matchup (details redacted)');
      rethrow;
    }
  }

  /// Historical callers may still expect [] on failure; the live dashboard
  /// MUST use the strict methods to distinguish an outage from empty data.
  Future<List<MatchupTeam>> getMatchupTeams(String bookingId) async {
    try {
      return await getMatchupTeamsStrict(bookingId);
    } catch (_) {
      debugPrint('Error fetching matchup teams (details redacted)');
      return [];
    }
  }

  Future<List<MatchupTeam>> getMatchupTeamsStrict(String bookingId) async {
    final response = await _supabase
        .from('matchup_teams')
        .select('*')
        .eq('booking_id', bookingId)
        .order('joined_at', ascending: true);

    final rows = (response as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return [];

    final teamIds = rows.map((r) => r['team_id']?.toString())
        .whereType<String>().toList();
    final teamsRes = await _supabase
        .from('teams_public')
        .select('id, name, logo_url, captain_id')
        .inFilter('id', teamIds);
    final teamsMap = {
      for (var t in (teamsRes as List)) t['id'].toString(): t
    };

    return rows.map((row) {
      final teamId = row['team_id']?.toString();
      final teamData = teamsMap[teamId];
      final combined = Map<String, dynamic>.from(row);
      if (teamData != null) combined['teams'] = teamData;
      return MatchupTeam.fromMap(combined);
    }).toList();
  }

  Future<List<MatchupResult>> getMatchupResults(String bookingId) async {
    try {
      return await getMatchupResultsStrict(bookingId);
    } catch (_) {
      debugPrint('Error fetching matchup results (details redacted)');
      return [];
    }
  }

  Future<List<MatchupResult>> getMatchupResultsStrict(String bookingId) async {
    final response = await _supabase
        .from('matchup_results')
        .select('*')
        .eq('booking_id', bookingId)
        .order('created_at', ascending: true);
    return (response as List).map(
      (row) => MatchupResult.fromMap(row),
    ).toList();
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
    } catch (_) {
      debugPrint('Error fetching team head to head (details redacted)');
      return null;
    }
  }

  /// Compatibility view: old consumers may treat a failure as no rows.
  /// Critical result/history screens MUST call the strict version instead.
  Future<List<Map<String, dynamic>>> getAllHeadToHeadForTeam(
      String teamId) async {
    try {
      return await getAllHeadToHeadForTeamStrict(teamId);
    } catch (_) {
      debugPrint('Matchup head-to-head lookup failed (details redacted)');
      return [];
    }
  }

  /// Team IDs are canonical UUIDs. PostgREST's .or() accepts a filter
  /// expression, so never interpolate an untrusted deep-link or UI string
  /// without validating it first.
  static bool isCanonicalTeamId(String id) =>
      RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
        r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(id);

  /// A failed source read is UNKNOWN, not verified empty history. This
  /// deliberately avoids embedding the private teams table in a public
  /// head-to-head read: only the approved teams_public projection supplies
  /// opponent names and logos.
  ///
  /// The arguments for the PostgREST OR filter are UUIDs, never arbitrary
  /// text from a deep link or player input.
  Future<List<Map<String, dynamic>>> getAllHeadToHeadForTeamStrict(
      String teamId) async {
    if (!isCanonicalTeamId(teamId)) {
      throw const FormatException('Invalid canonical team ID');
    }
    final raw = await _supabase
        .from('team_head_to_head')
        .select('team_a_id,team_b_id,team_a_wins,team_b_wins,draws')
        .or('team_a_id.eq.$teamId,team_b_id.eq.$teamId');
    final rows = List<Map<String, dynamic>>.from(raw as List);
    // Only request public opponent names for rows truly involving this team.
    // Never broaden a second query using unrelated or malformed upstream IDs.
    final scopedRows = rows.where((row) {
      final a = row['team_a_id'];
      final b = row['team_b_id'];
      return a is String && b is String && a != b &&
          isCanonicalTeamId(a) && isCanonicalTeamId(b) &&
          (a == teamId || b == teamId);
    }).toList(growable: false);
    if (scopedRows.isEmpty) return [];
    final participantIds = <String>{
      for (final row in scopedRows) row['team_a_id'] as String,
      for (final row in scopedRows) row['team_b_id'] as String,
    };
    final teams = await _supabase
        .from('teams_public')
        .select('id,name,logo_url')
        .inFilter('id', participantIds.toList());
    return withPublicTeamNames(
      teamId,
      scopedRows,
      List<Map<String, dynamic>>.from(teams as List),
    );
  }

  /// Reject cross-team results even if an upstream cache returns mixed rows.
  /// Copy ONLY the approved aggregate counts and public team metadata.
  static List<Map<String, dynamic>> withPublicTeamNames(
    String teamId,
    Iterable<Map<String, dynamic>> records,
    Iterable<Map<String, dynamic>> publicTeams,
  ) {
    if (!isCanonicalTeamId(teamId)) return const [];
    final teamsById = <String, Map<String, dynamic>>{
      for (final team in publicTeams)
        if (team['id'] is String &&
            isCanonicalTeamId(team['id'] as String))
          team['id'] as String: <String, dynamic>{
            'id': team['id'],
            if (team['name'] is String) 'name': team['name'],
            if (team['logo_url'] is String) 'logo_url': team['logo_url'],
          },
    };
    final safe = <Map<String, dynamic>>[];
    for (final rec in records) {
      final a = rec['team_a_id'];
      final b = rec['team_b_id'];
      if (a is! String || b is! String || a == b ||
          !isCanonicalTeamId(a) || !isCanonicalTeamId(b) ||
          (a != teamId && b != teamId)) continue;
      safe.add({
        'team_a_id': a,
        'team_b_id': b,
        'team_a_wins': rec['team_a_wins'],
        'team_b_wins': rec['team_b_wins'],
        'draws': rec['draws'],
        if (teamsById.containsKey(a)) 'team_a': teamsById[a],
        if (teamsById.containsKey(b)) 'team_b': teamsById[b],
      });
    }
    return safe;
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
      // Only authoritative completed matchup outcomes count. A partial or
      // malformed record must not magically award a draw and one point.
      // Team challenge results use a separate two-captain agreement flow.
      if (!stats.containsKey(r.teamAId) ||
          !stats.containsKey(r.teamBId) ||
          r.teamAId == r.teamBId ||
          (r.outcome != 'team_a_win' &&
              r.outcome != 'team_b_win' &&
              r.outcome != 'draw')) {
        continue;
      }

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
      } else if (r.outcome == 'draw') {
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
