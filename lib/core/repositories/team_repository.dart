import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../constants/egypt_governorates.dart';
import '../services/logger_service.dart';
import 'team/team_opponent_service.dart';
import 'team/team_payload_builder.dart';
import 'team/team_roster_coordinator.dart';

class TeamRepository {
  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  late final TeamRosterCoordinator _rosterCoordinator;

  TeamRepository({
    SupabaseClient? client,
    TeamRosterCoordinator? rosterCoordinator,
  }) : _client = client {
    _rosterCoordinator = rosterCoordinator ?? TeamRosterCoordinator(client: client);
  }

  Future<List<String>> getTeamMemberUids(String teamId) =>
      _rosterCoordinator.getTeamMemberUids(teamId);

  Future<List<String>> getTeamPlayerImages(List<String> memberUids) =>
      _rosterCoordinator.getTeamPlayerImages(memberUids);

  /// Fetch list of player profiles (id, name, phone, position) for members of a team
  Future<List<Map<String, String>>> getTeamMemberProfiles(String teamId) =>
      _rosterCoordinator.getTeamMemberProfiles(teamId);

  Future<bool> checkIsTeamOfficial(String teamId) =>
      TeamOpponentService.checkIsTeamOfficial(
        supabase: _supabase,
        repository: this,
        teamId: teamId,
      );

 /// تحديث نتائج المباراة ونقاط الـ Elo فقط للمباريات الرسمية
 Future<void> updateMatchResult(String bookingId, String homeTeamId, String awayTeamId, MatchOutcome finalOutcome) async {
   // Legacy compatibility: competitive results must pass the server-side
   // atomic result workflow. This method no longer mutates bookings directly.
   try {
     final response = await _supabase.rpc(
       'submit_challenge_result_atomic',
       params: {
         'p_booking_id': bookingId,
         'p_team_id': homeTeamId,
         'p_outcome': finalOutcome.name,
       },
     );
     if (response is Map && response['success'] == false) {
       throw Exception(response['error']?.toString() ?? 'فشل تحديث نتيجة المباراة');
     }
   } catch (e) {
     debugPrint('Error updating match result through atomic RPC: $e');
     rethrow;
   }
 }
 Future<Set<String>> getUserCaptainTeamIds(String userId) async {
   try {
     return await getUserCaptainTeamIdsStrict(userId);
   } catch (e) {
     debugPrint('Error getting user captain teams: $e');
     return <String>{};
   }
 }

 /// Strict variant for flows where an empty result has business meaning.
 /// Propagates query failures so callers can distinguish "not a captain"
 /// from "could not verify captain access".
 Future<Set<String>> getUserCaptainTeamIdsStrict(String userId) async {
   final response = await _supabase
       .from('teams_public')
       .select('id')
       .eq('captain_id', userId);
   return (response as List)
       .map((row) => row['id']?.toString() ?? '')
       .where((id) => id.isNotEmpty)
       .toSet();
 }

 /// Returns every team membership for the signed-in user.
 Future<Set<String>> getUserTeamIdsStrict(String userId) async {
   final response = await _supabase
       .from('team_members')
       .select('team_id')
       .eq('user_id', userId);
   return (response as List)
       .map((row) => row['team_id']?.toString() ?? '')
       .where((id) => id.isNotEmpty)
       .toSet();
 }

 Future<Team?> getUserTeam(String userId) async {
   try {
     return await getUserTeamStrict(userId);
   } catch (e) {
     debugPrint('Error getting user team: $e');
     return null;
   }
 }

 /// Strict lookup for screens that must distinguish no membership from a
 /// failed membership/team query.
 Future<Team?> getUserTeamStrict(String userId) async {
   final response = await _supabase
       .from('team_members')
       .select('team_id')
       .eq('user_id', userId);
   final List membership = response as List;
   if (membership.isEmpty) return null;

   // Existing behavior selects the first membership. Multiple-team selection
   // policy remains a product decision; no ordering is inferred here.
   final teamId = membership.first['team_id']?.toString();
   if (teamId == null || teamId.isEmpty) return null;
   return await getTeamStrict(teamId);
 }

 Future<String?> createTeam(Map<String, dynamic> data) async {
  final memberUids = List<String>.from((data['memberUids'] as List? ?? []).map((e) => e.toString()).where((e) => !e.startsWith('guest_')));
  final pgData = TeamPayloadBuilder.buildCreatePayload(data);
  final response = await _supabase.rpc('create_team_atomic', params: {
    'p_data': pgData,
    'p_member_uids': memberUids,
  });
  if (response is Map && response['success'] == true) return response['team_id']?.toString();
  throw Exception(response is Map ? response['error'] ?? 'فشل إنشاء الفريق' : 'فشل إنشاء الفريق');
 }
  Future<Team?> getTeam(String id) async {
    try {
      return await getTeamStrict(id);
    } catch (e) {
      debugPrint('Error getting team: $e');
      return null;
    }
  }

  /// Strict team lookup for screens that must distinguish a missing team from
  /// a failed network/query request.
  Future<Team?> getTeamStrict(String id) async {
    final response = await _supabase
        .from('teams_public')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;

    final memberUids = await getTeamMemberUids(id);
    final playerImages = await getTeamPlayerImages(memberUids);

    final data = Map<String, dynamic>.from(response);
    data['memberUids'] = memberUids;
    data['playerImages'] = playerImages;
    data['playersCount'] = memberUids.length;

    return Team.fromFirestore(data, id);
  }

  Future<List<Team>> fetchTeamsDirectly({String? governorate}) async {
    try {
      final response = await _supabase.from('teams_public').select().limit(50);
      return (response as List).map((data) {
        if (governorate != null && governorate.isNotEmpty && governorate != 'All') {
          final dbGov = (data['governorate'] ?? '').toString().trim();
          final stdDbGov = EgyptGovernorates.resolveGoogleName(dbGov) ?? dbGov;
          final stdFilterGov = EgyptGovernorates.resolveGoogleName(governorate) ?? governorate;

          final matches = stdDbGov.toLowerCase() == stdFilterGov.toLowerCase() ||
              dbGov.toLowerCase() == governorate.toLowerCase();

          if (!matches) {
            return null;
          }
        }
        return Team.fromFirestore(data as Map<String, dynamic>, data['id'].toString());
      }).whereType<Team>().toList();
    } catch (e) {
      debugPrint('Error fetching teams directly: $e');
      return [];
    }
  }

  Stream<List<Team>> getTeams({String? governorate}) async* {
    final direct = await fetchTeamsDirectly(governorate: governorate);
    yield direct;
  }

  /// جلب كود الدعوة النشط للفريق (للكابتن أو الأدمن فقط عبر RPC آمنة)
  Future<String?> getTeamInviteCode(String teamId) async {
    try {
      final res = await _supabase.rpc('get_team_invite_code', params: {
        'p_team_id': teamId,
      });
      if (res is Map && res['success'] == true) {
        return res['invite_code']?.toString();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting team invite code: $e');
      return null;
    }
  }

  Future<List<Team>> searchOpponentTeams(String query) =>
      TeamOpponentService.searchOpponentTeams(
        supabase: _supabase,
        query: query,
      );

  Future<List<Team>> getPreviousOpponents(String teamId) =>
      TeamOpponentService.getPreviousOpponents(
        supabase: _supabase,
        repository: this,
        teamId: teamId,
      );

 Future<Map<String, int>> getHeadToHeadStats(String team1Id, String team2Id) async {
 try {
 final response = await _supabase
 .from('bookings')
 .select('player_team_id, opponent_team_id, final_outcome, winner_team_id')
 .eq('status', 'completed')
 .or('and(player_team_id.eq.$team1Id,opponent_team_id.eq.$team2Id),and(player_team_id.eq.$team2Id,opponent_team_id.eq.$team1Id)');

 return TeamPayloadBuilder.calculateHeadToHead(response as List, team1Id, team2Id);
 } catch (e) {
 debugPrint('Error getting head to head stats: $e');
 return {'teamAWins': 0, 'draws': 0, 'teamBWins': 0, 'totalMatches': 0};
 }
 }

  @Deprecated('Use lookupChallengeCode or team ID instead of captain phone')
  Future<Team?> getTeamByCaptainPhone(String phone) async => null;

  Future<void> addMemberToTeam(String teamId, String userId, String imageUrl) =>
      _rosterCoordinator.addMemberToTeam(teamId, userId, imageUrl);

  Future<void> removeMemberFromTeam(String teamId, String userId, String imageUrl) =>
      _rosterCoordinator.removeMemberFromTeam(teamId, userId, imageUrl);

  /// نقل شارة قيادة الفريق ذرياً
  Future<void> transferCaptaincy(String teamId, String newCaptainId) =>
      _rosterCoordinator.transferCaptaincy(teamId, newCaptainId);

 Future<bool> updateTeam(String teamId, Map<String, dynamic> data) async {
  try {
    final pgData = TeamPayloadBuilder.buildUpdatePayload(data);
    if (pgData.isEmpty) return true;
    final response = await _supabase.rpc('update_team_atomic', params: {'p_team_id': teamId, 'p_data': pgData});
    return response is Map && response['success'] == true;
  } catch (e) { debugPrint('Error updating team: $e'); return false; }
 }

 Future<bool> deleteTeam(String teamId) async {
  final response = await _supabase.rpc('delete_team_atomic', params: {'p_team_id': teamId});
  if (response is Map && response['success'] == true) return true;
  throw Exception(response is Map ? response['error'] ?? 'فشل حذف الفريق' : 'فشل حذف الفريق');
 }
 Future<bool> has1v1Champion(String teamId) async {
 try {
 final response = await _supabase.rpc(
 'check_team_has_1v1_champion',
 params: {'p_team_id': teamId},
 );
 return response == true;
 } catch (e) {
 debugPrint('Error checking if team has 1v1 champion: $e');
 return false;
 }
 }

  /// Stream user's membership changes
  Stream<List<Map<String, dynamic>>> streamUserMembership(String userId) =>
      _rosterCoordinator.streamUserMembership(userId);

  /// Stream single team updates (reads initially from public view, then listens to realtime)
  Stream<List<Map<String, dynamic>>> streamTeam(String teamId) async* {
    try {
      final initialDoc = await _supabase
          .from('teams_public')
          .select()
          .eq('id', teamId)
          .maybeSingle();
      if (initialDoc != null) {
        yield [Map<String, dynamic>.from(initialDoc)];
      }
    } catch (e) {
      VSPLogger.w('Initial public team fetch notice: $e');
    }

    yield* _supabase
        .from('teams')
        .stream(primaryKey: ['id'])
        .eq('id', teamId)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) => sink.add([]),
        )
        .handleError((err) {
          VSPLogger.w('Team realtime stream notice: $err');
        });
  }

  /// توليد أو جلب كود التحدي النشط للفريق (للكابتن فقط)
  Future<Map<String, dynamic>> generateChallengeCode(String teamId) async {
    try {
      final res = await _supabase.rpc('generate_team_challenge_code', params: {
        'p_team_id': teamId,
      });
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'success': false, 'error': 'UNEXPECTED_RESPONSE'};
    } catch (e) {
      VSPLogger.e('Error generating challenge code: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// البحث عن الفريق المنافس عبر كود التحدي
  Future<Map<String, dynamic>> lookupChallengeCode(String code) async {
    try {
      final res = await _supabase.rpc('lookup_challenge_code', params: {
        'p_code': code.trim().toUpperCase(),
      });
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'success': false, 'error': 'UNEXPECTED_RESPONSE'};
    } catch (e) {
      VSPLogger.e('Error looking up challenge code: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
