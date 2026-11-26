import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/logger_service.dart';
import '../../data/models/team_gamification_models.dart';

class GamificationRepository {
  GamificationRepository._();
  static final GamificationRepository instance = GamificationRepository._();

  SupabaseClient get _db => Supabase.instance.client;

  Future<({String monthKey, List<MonthlyRankingEntry> teams})> getMonthlyCompetitiveRanking({
    String? monthKey,
    String? governorate,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final govParam = (governorate == null || governorate == 'All' || governorate.trim().isEmpty)
          ? null
          : governorate.trim();
      final res = await _db.rpc('get_monthly_competitive_ranking', params: {
        'p_month_key': monthKey,
        'p_governorate': govParam,
        'p_limit': limit,
        'p_offset': offset,
      });
      if (res is Map) {
        final mk = (res['month_key'] ?? '').toString();
        final list = (res['teams'] as List<dynamic>? ?? [])
            .map((e) => MonthlyRankingEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return (monthKey: mk, teams: list);
      }
    } catch (e) {
      VSPLogger.w('getMonthlyCompetitiveRanking error: $e');
    }
    return (monthKey: '', teams: <MonthlyRankingEntry>[]);
  }

  Future<List<MostActiveTeamEntry>> getMostActiveTeamsRanking({
    String? seasonId,
    String? governorate,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final govParam = (governorate == null || governorate == 'All' || governorate.trim().isEmpty)
          ? null
          : governorate.trim();
      final res = await _db.rpc('get_most_active_teams_ranking', params: {
        'p_season_id': seasonId,
        'p_governorate': govParam,
        'p_limit': limit,
        'p_offset': offset,
      });
      if (res is Map) {
        return (res['teams'] as List<dynamic>? ?? [])
            .map((e) => MostActiveTeamEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      VSPLogger.w('getMostActiveTeamsRanking error: $e');
    }
    return [];
  }

  Future<TeamGamificationProfile?> getTeamGamificationProfile(String teamId) async {
    if (teamId.trim().isEmpty) return null;
    try {
      final res = await _db.rpc('get_team_gamification_profile', params: {
        'p_team_id': teamId,
      });
      if (res is Map && res['success'] == true) {
        return TeamGamificationProfile.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (e) {
      VSPLogger.w('getTeamGamificationProfile error: $e');
    }
    return null;
  }

  Future<({bool isRepeat, int seasonMatches, num winXp, num drawXp, num lossXp})> getChallengeOpponentRepeatStatus({
    required String teamId,
    required String opponentTeamId,
  }) async {
    try {
      final res = await _db.rpc('get_challenge_opponent_repeat_status', params: {
        'p_team_id': teamId,
        'p_opponent_team_id': opponentTeamId,
      });
      if (res is Map) {
        return (
          isRepeat: res['is_repeat'] == true,
          seasonMatches: (res['season_matches'] as num?)?.toInt() ?? 0,
          winXp: (res['win_xp'] as num?) ?? 80,
          drawXp: (res['draw_xp'] as num?) ?? 65,
          lossXp: (res['loss_xp'] as num?) ?? 50,
        );
      }
    } catch (e) {
      VSPLogger.w('getChallengeOpponentRepeatStatus error: $e');
    }
    return (isRepeat: false, seasonMatches: 0, winXp: 80, drawXp: 65, lossXp: 50);
  }

  Future<bool> submitImmortalPlayerSize({
    required String entitlementId,
    required String targetUserId,
    required String jerseySize,
    String? contactPhone,
    String? deliveryAddress,
  }) async {
    final res = await _db.rpc('submit_immortal_player_size', params: {
      'p_entitlement_id': entitlementId,
      'p_target_user_id': targetUserId,
      'p_jersey_size': jerseySize,
      'p_contact_phone': contactPhone,
      'p_delivery_address': deliveryAddress,
    });
    return res is Map && res['success'] == true;
  }

  Future<Map<String, dynamic>> bookStadiumWithMonthlyAward({
    required String awardId,
    required String stadiumId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final res = await _db.rpc('book_stadium_with_monthly_award_atomic', params: {
      'p_award_id': awardId,
      'p_stadium_id': stadiumId,
      'p_start_time': startTime.toUtc().toIso8601String(),
      'p_end_time': endTime.toUtc().toIso8601String(),
    });
    if (res is Map) return Map<String, dynamic>.from(res);
    return {'success': false, 'error': 'UNKNOWN_ERROR'};
  }

  Future<List<StrongestTeamEvent>> getStrongestTeamEvents({String? governorate}) async {
    try {
      var query = _db
          .from('strongest_team_events')
          .select('''
            *,
            strongest_team_tests(*),
            strongest_team_participants(*, teams(id, name, logo_url, governorate)),
            strongest_team_scores(*)
          ''')
          .neq('status', 'draft');

      if (governorate != null && governorate != 'All' && governorate.trim().isNotEmpty) {
        query = query.ilike('governorate', governorate.trim());
      }

      final data = await query.order('event_date', ascending: false);
      return (data as List)
          .map((e) => StrongestTeamEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      VSPLogger.w('getStrongestTeamEvents error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> joinStrongestTeamEvent({
    required String eventId,
    required String teamId,
    required List<String> selectedPlayerIds,
    required String goalkeeperUserId,
  }) async {
    final res = await _db.rpc('join_strongest_team_event_atomic', params: {
      'p_event_id': eventId,
      'p_team_id': teamId,
      'p_selected_player_ids': selectedPlayerIds,
      'p_goalkeeper_user_id': goalkeeperUserId,
    });
    if (res is Map) return Map<String, dynamic>.from(res);
    return {'success': false, 'error': 'UNKNOWN_ERROR'};
  }

  Future<bool> isStrongestTeamOrderPaid(String orderReference) async {
    try {
      final row = await _db
          .from('strongest_team_orders')
          .select('payment_status')
          .eq('order_reference', orderReference)
          .maybeSingle();
      return row?['payment_status'] == 'paid';
    } catch (_) {
      return false;
    }
  }
}
