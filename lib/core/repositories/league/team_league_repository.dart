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
  final String? confirmedOutcome;
  final String resultStatus; // 'pending', 'awaiting_result', 'result_one_side', 'confirmed', 'disputed', 'locked'
  final DateTime? scheduledTime;
  final DateTime? matchDay;
  final String? stadiumName;
  final String? bookingId;
  final String status;
  final bool isCompleted;
  final DateTime? resultConfirmedAt;
  final DateTime? resultLockedAt;
  final DateTime? disputeCreatedAt;
  final String? myTeamSubmission; // 'win', 'draw', 'loss'
  final String? opponentTeamSubmission;

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
    this.confirmedOutcome,
    required this.resultStatus,
    this.scheduledTime,
    this.matchDay,
    this.stadiumName,
    this.bookingId,
    required this.status,
    required this.isCompleted,
    this.resultConfirmedAt,
    this.resultLockedAt,
    this.disputeCreatedAt,
    this.myTeamSubmission,
    this.opponentTeamSubmission,
  });

  bool get isLocked =>
      resultStatus == 'locked' ||
      (resultConfirmedAt != null &&
          DateTime.now().isAfter(resultConfirmedAt!.add(const Duration(minutes: 15))));

  bool get isDisputed => resultStatus == 'disputed';

  bool get isConfirmed => resultStatus == 'confirmed' || resultStatus == 'locked';

  int get roundIndex => weekNumber;

  bool get canCorrectResult =>
      resultStatus == 'confirmed' &&
      resultConfirmedAt != null &&
      DateTime.now().isBefore(resultConfirmedAt!.add(const Duration(minutes: 15)));

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
      confirmedOutcome: json['confirmed_outcome']?.toString(),
      resultStatus: json['result_status']?.toString() ?? 'pending',
      scheduledTime: json['scheduled_time'] != null
          ? DateTime.tryParse(json['scheduled_time'].toString())?.toLocal()
          : null,
      matchDay: json['match_day'] != null
          ? DateTime.tryParse(json['match_day'].toString())?.toLocal()
          : null,
      stadiumName: json['stadium_name']?.toString(),
      bookingId: json['booking_id']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      isCompleted: json['is_completed'] == true,
      resultConfirmedAt: json['result_confirmed_at'] != null
          ? DateTime.tryParse(json['result_confirmed_at'].toString())?.toLocal()
          : null,
      resultLockedAt: json['result_locked_at'] != null
          ? DateTime.tryParse(json['result_locked_at'].toString())?.toLocal()
          : null,
      disputeCreatedAt: json['dispute_created_at'] != null
          ? DateTime.tryParse(json['dispute_created_at'].toString())?.toLocal()
          : null,
      myTeamSubmission: json['my_team_submission']?.toString(),
      opponentTeamSubmission: json['opponent_team_submission']?.toString(),
    );
  }
}

class TeamLeagueStandingItem {
  final String teamId;
  final String teamName;
  final String? teamLogoUrl;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int points;
  final int rank;

  TeamLeagueStandingItem({
    required this.teamId,
    required this.teamName,
    this.teamLogoUrl,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.points,
    required this.rank,
  });

  factory TeamLeagueStandingItem.fromJson(Map<String, dynamic> json) {
    return TeamLeagueStandingItem(
      teamId: json['team_id']?.toString() ?? '',
      teamName: json['team_name']?.toString() ?? '',
      teamLogoUrl: json['team_logo_url']?.toString(),
      played: (json['played'] as num?)?.toInt() ?? 0,
      won: (json['won'] as num?)?.toInt() ?? 0,
      drawn: (json['drawn'] as num?)?.toInt() ?? 0,
      lost: (json['lost'] as num?)?.toInt() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 1,
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
  final String? governorate;
  final int matchIntervalDays;
  final int paidByCreatorCount;
  final bool isCreator;
  final String? championTeamId;
  final String? championTeamName;
  final int joinedTeamsCount;
  final int paidTeamsCount;
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
    this.governorate,
    required this.matchIntervalDays,
    required this.paidByCreatorCount,
    required this.isCreator,
    this.championTeamId,
    this.championTeamName,
    required this.joinedTeamsCount,
    required this.paidTeamsCount,
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
      governorate: json['governorate']?.toString() ?? 'Cairo',
      matchIntervalDays: (json['match_interval_days'] as num?)?.toInt() ?? 7,
      paidByCreatorCount: (json['paid_by_creator_count'] as num?)?.toInt() ?? 1,
      isCreator: json['is_creator'] == true,
      championTeamId: json['champion_team_id']?.toString(),
      championTeamName: json['champion_team_name']?.toString(),
      joinedTeamsCount: (json['joined_teams_count'] as num?)?.toInt() ?? rawTeams.length,
      paidTeamsCount: (json['paid_teams_count'] as num?)?.toInt() ?? 0,
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

  /// Fetches configured entry fee per team from league_settings table
  Future<double> getTeamLeagueEntryFee() async {
    try {
      final res = await _supabase
          .from('league_settings')
          .select('setting_value')
          .eq('setting_key', 'team_league_entry_fee')
          .maybeSingle();
      if (res != null && res['setting_value'] != null) {
        return double.tryParse(res['setting_value'].toString()) ?? 30.0;
      }
    } catch (e) {
      debugPrint('Notice getting team league entry fee: $e');
    }
    return 30.0;
  }

  /// Fetches the active private team league for a given team
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

  /// Creates a new private team league with 4 to 8 teams and flexible payment options
  Future<Map<String, dynamic>> createTeamLeague({
    required String teamId,
    required String leagueName,
    String? governorate,
    int maxTeams = 4,
    int intervalDays = 7,
    String payOption = 'my_team', // 'my_team', 'all', 'custom'
    int customPaidCount = 1,
  }) async {
    final res = await _supabase.rpc(
      'create_team_league',
      params: {
        'p_league_name': leagueName.trim(),
        'p_team_id': teamId,
        'p_governorate': governorate ?? 'Cairo',
        'p_max_teams': maxTeams,
        'p_interval_days': intervalDays,
        'p_pay_option': payOption,
        'p_paid_teams_count': customPaidCount,
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

  /// Joins an existing private team league
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

  /// Submits non-numerical match result ('win', 'draw', 'loss')
  Future<Map<String, dynamic>> submitMatchResult({
    required String matchId,
    required String teamId,
    required String result, // 'win', 'draw', 'loss'
  }) async {
    final res = await _supabase.rpc(
      'submit_team_league_match_result',
      params: {
        'p_match_id': matchId,
        'p_team_id': teamId,
        'p_result': result,
      },
    );
    if (res == null || res['success'] != true) {
      throw Exception(res?['message'] ?? 'فشل تسجيل نتيجة المباراة');
    }
    return Map<String, dynamic>.from(res as Map);
  }

  /// League Creator resolves dispute ('home_win', 'draw', 'away_win')
  Future<Map<String, dynamic>> resolveDispute({
    required String matchId,
    required String resolution, // 'home_win', 'draw', 'away_win'
  }) async {
    final res = await _supabase.rpc(
      'resolve_team_league_dispute',
      params: {
        'p_match_id': matchId,
        'p_resolution': resolution,
      },
    );
    if (res == null || res['success'] != true) {
      throw Exception(res?['message'] ?? 'فشل اعتماد نتيجة النزاع');
    }
    return Map<String, dynamic>.from(res as Map);
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
