import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamLeagueParticipant {
  final String id;
  final String name;
  final String? logoUrl;
  final String? captainPhone;

  TeamLeagueParticipant({
    required this.id,
    required this.name,
    this.logoUrl,
    this.captainPhone,
  });

  factory TeamLeagueParticipant.fromJson(Map<String, dynamic> json) {
    return TeamLeagueParticipant(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'فريق',
      logoUrl: json['logo_url']?.toString(),
      captainPhone: json['captain_phone']?.toString(),
    );
  }
}

class TeamLeagueMatch {
  final String id;
  final String championshipId;
  final int weekNumber;
  final int matchIndex;
  final String stage;
  final String homeTeamId;
  final String homeTeamName;
  final String awayTeamId;
  final String awayTeamName;
  final int? homeScore;
  final int? awayScore;
  final String? winnerId;
  final String? winnerName;
  final DateTime? scheduledTime;
  final String? stadiumName;
  final String? bookingId;
  final String status;
  final bool isCompleted;

  TeamLeagueMatch({
    required this.id,
    required this.championshipId,
    required this.weekNumber,
    required this.matchIndex,
    required this.stage,
    required this.homeTeamId,
    required this.homeTeamName,
    required this.awayTeamId,
    required this.awayTeamName,
    this.homeScore,
    this.awayScore,
    this.winnerId,
    this.winnerName,
    this.scheduledTime,
    this.stadiumName,
    this.bookingId,
    required this.status,
    required this.isCompleted,
  });

  factory TeamLeagueMatch.fromJson(Map<String, dynamic> json) {
    return TeamLeagueMatch(
      id: json['id']?.toString() ?? '',
      championshipId: json['championship_id']?.toString() ?? '',
      weekNumber: (json['week_number'] as num?)?.toInt() ?? 1,
      matchIndex: (json['match_index'] as num?)?.toInt() ?? 0,
      stage: json['stage']?.toString() ?? 'league',
      homeTeamId: json['home_team_id']?.toString() ?? '',
      homeTeamName: json['home_team_name']?.toString() ?? 'فريق 1',
      awayTeamId: json['away_team_id']?.toString() ?? '',
      awayTeamName: json['away_team_name']?.toString() ?? 'فريق 2',
      homeScore: (json['home_score'] as num?)?.toInt(),
      awayScore: (json['away_score'] as num?)?.toInt(),
      winnerId: json['winner_id']?.toString(),
      winnerName: json['winner_name']?.toString(),
      scheduledTime: json['scheduled_time'] != null
          ? DateTime.tryParse(json['scheduled_time'].toString())?.toLocal()
          : null,
      stadiumName: json['stadium_name']?.toString(),
      bookingId: json['booking_id']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      isCompleted: json['is_completed'] == true,
    );
  }
}

class TeamLeagueStandingItem {
  final String teamId;
  final String teamName;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int points;

  TeamLeagueStandingItem({
    required this.teamId,
    required this.teamName,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
  });

  factory TeamLeagueStandingItem.fromJson(Map<String, dynamic> json) {
    return TeamLeagueStandingItem(
      teamId: json['team_id']?.toString() ?? '',
      teamName: json['team_name']?.toString() ?? '',
      played: (json['played'] as num?)?.toInt() ?? 0,
      won: (json['won'] as num?)?.toInt() ?? 0,
      drawn: (json['drawn'] as num?)?.toInt() ?? 0,
      lost: (json['lost'] as num?)?.toInt() ?? 0,
      goalsFor: (json['goals_for'] as num?)?.toInt() ?? 0,
      goalsAgainst: (json['goals_against'] as num?)?.toInt() ?? 0,
      goalDifference: (json['goal_difference'] as num?)?.toInt() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }
}

class TeamLeagueData {
  final String id;
  final String name;
  final String status;
  final double entryFee;
  final int maxTeams;
  final String ownerId;
  final String? championTeamId;
  final String? championTeamName;
  final int joinedTeamsCount;
  final List<TeamLeagueParticipant> teams;
  final List<TeamLeagueMatch> matches;
  final List<TeamLeagueStandingItem> standings;

  TeamLeagueData({
    required this.id,
    required this.name,
    required this.status,
    required this.entryFee,
    required this.maxTeams,
    required this.ownerId,
    this.championTeamId,
    this.championTeamName,
    required this.joinedTeamsCount,
    required this.teams,
    required this.matches,
    required this.standings,
  });

  factory TeamLeagueData.fromJson(Map<String, dynamic> json) {
    final rawTeams = json['teams'] as List? ?? [];
    final rawMatches = json['matches'] as List? ?? [];
    final rawStandings = json['standings'] as List? ?? [];

    return TeamLeagueData(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      entryFee: (json['entry_fee'] as num?)?.toDouble() ?? 30.0,
      maxTeams: (json['max_teams'] as num?)?.toInt() ?? 4,
      ownerId: json['owner_id']?.toString() ?? '',
      championTeamId: json['champion_team_id']?.toString(),
      championTeamName: json['champion_team_name']?.toString(),
      joinedTeamsCount: (json['joined_teams_count'] as num?)?.toInt() ?? rawTeams.length,
      teams: rawTeams
          .map((e) => TeamLeagueParticipant.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      matches: rawMatches
          .map((e) => TeamLeagueMatch.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      standings: rawStandings
          .map((e) => TeamLeagueStandingItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class TeamLeagueRepository {
  final SupabaseClient? _client;

  TeamLeagueRepository({SupabaseClient? client}) : _client = client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// Fetches the active 4-team league for a given team
  Future<TeamLeagueData?> getTeamActiveLeague(String teamId) async {
    try {
      final res = await _supabase.rpc(
        'get_team_active_league',
        params: {'p_team_id': teamId},
      );
      if (res == null) return null;
      return TeamLeagueData.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      debugPrint('Error getting team active league: $e');
      return null;
    }
  }

  /// Creates a new 4-team league with 30 EGP entry fee per team
  Future<Map<String, dynamic>> createTeamLeague({
    required String teamId,
    required String leagueName,
    String? governorate,
  }) async {
    final res = await _supabase.rpc(
      'create_team_league',
      params: {
        'p_league_name': leagueName.trim(),
        'p_team_id': teamId,
        'p_governorate': governorate ?? 'Cairo',
      },
    );
    if (res == null || res['success'] != true) {
      throw Exception(res?['message'] ?? 'فشل إنشاء الدوري');
    }
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> getTeamLeaguePaymentStatus({
    required String championshipId,
    required String teamId,
  }) async {
    final res = await _supabase.rpc('get_team_league_payment_status', params: {
      'p_championship_id': championshipId,
      'p_team_id': teamId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  /// Joins an existing 4-team league using the championship id / code
  Future<Map<String, dynamic>> joinTeamLeague({
    required String championshipId,
    required String teamId,
  }) async {
    final res = await _supabase.rpc(
      'join_team_league',
      params: {
        'p_championship_id': championshipId.trim(),
        'p_team_id': teamId,
      },
    );
    if (res == null || res['success'] != true) {
      throw Exception(res?['message'] ?? 'فشل الانضمام للدوري');
    }
    return Map<String, dynamic>.from(res as Map);
  }

  /// Records the score of a league match and updates standings & podium
  Future<void> recordLeagueMatchResult({
    required String matchId,
    required int homeScore,
    required int awayScore,
    int? homePenalties,
    int? awayPenalties,
  }) async {
    final res = await _supabase.rpc(
      'record_league_match_result',
      params: {
        'p_match_id': matchId,
        'p_home_score': homeScore,
        'p_away_score': awayScore,
        'p_home_penalties': homePenalties,
        'p_away_penalties': awayPenalties,
      },
    );
    if (res == null || res['success'] != true) {
      throw Exception(res?['message'] ?? 'فشل تسجيل نتيجة المباراة');
    }
  }

  /// Links a pitch booking to a league match
  Future<void> linkLeagueMatchBooking({
    required String matchId,
    required String bookingId,
    DateTime? scheduledTime,
    String? stadiumName,
  }) async {
    final res = await _supabase.rpc(
      'link_league_match_booking',
      params: {
        'p_match_id': matchId,
        'p_booking_id': bookingId,
        'p_scheduled_time': scheduledTime?.toUtc().toIso8601String(),
        'p_stadium_name': stadiumName,
      },
    );
    if (res == null || res['success'] != true) {
      throw Exception(res?['message'] ?? 'فشل ربط الحجز بالمباراة');
    }
  }

  /// Cancels an open (unstarted) team league
  Future<void> cancelTeamLeague(String championshipId) async {
    final res = await _supabase.rpc(
      'cancel_team_league',
      params: {'p_championship_id': championshipId.trim()},
    );
    if (res == null || res['success'] != true) {
      throw Exception(res?['message'] ?? 'فشل إلغاء الدوري');
    }
  }
}
