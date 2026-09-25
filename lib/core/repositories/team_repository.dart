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
 try {
 // 1. التحقق من أصلية ورسمية الفريقين لمنع العبث بالترتيب عبر فرق وهمية
 final bool isHomeOfficial = await checkIsTeamOfficial(homeTeamId);
 final bool isAwayOfficial = await checkIsTeamOfficial(awayTeamId);

 final bool isOfficialRankedMatch = isHomeOfficial && isAwayOfficial;

 // 2. تحديث حالة الحجز والنتيجة في قاعدة البيانات
 await _supabase.from('bookings').update({
 'status': BookingStatus.completed.name,
 'final_outcome': finalOutcome.name,
 'is_official_match': isOfficialRankedMatch, // تميز الودية من الرسمية
 'updated_at': DateTime.now().toUtc().toIso8601String(),
 }).eq('id', bookingId);

 // 3. تحديث نقاط الـ Elo الرسمية فقط إذا كانت المباراة رسمية وليس بين فرق وهمية
 if (isOfficialRankedMatch) {
 debugPrint(' Official Ranked Match confirmed. Elo points calculated via server trigger.');
 } else {
 debugPrint('ℹ Friendly / Unverified match completed. Elo points preserved (No rank impact).');
 }
 } catch (e) {
 debugPrint('Error updating match result: $e');
 }
 }

 Future<Team?> getUserTeam(String userId) async {
 try {
 final response = await _supabase
 .from('team_members')
 .select('team_id')
 .eq('user_id', userId);
 final List membership = response as List;
 if (membership.isEmpty) return null;
 
 final teamId = membership.first['team_id'];
 return await getTeam(teamId);
 } catch (e) {
 debugPrint('Error getting user team: $e');
 return null;
 }
 }

 Future<String?> createTeam(Map<String, dynamic> data) async {
 try {
 final List memberUids = List.from(data['memberUids'] ?? []);
 if (memberUids.length > 12) {
 throw Exception("تنبيه: عذراً، اكتمل الحد الأقصى لأعضاء الفريق (12 لاعباً كحد أقصى).");
 }

 final pgData = TeamPayloadBuilder.buildCreatePayload(data);

 final response = await _supabase
 .from('teams')
 .insert(pgData)
 .select('id')
 .single();
 
 final teamId = response['id'].toString();

 if (memberUids.isNotEmpty) {
      final validMemberUids = memberUids
          .where((uid) => !uid.toString().startsWith('guest_'))
          .toList();
      if (validMemberUids.isNotEmpty) {
        final List<Map<String, dynamic>> memberRows = validMemberUids.map((uid) => {
          'team_id': teamId,
          'user_id': uid.toString(),
        }).toList();
        await _supabase.from('team_members').insert(memberRows);
      }
    }

  if (memberUids.length > 1) {
  for (int i = 1; i < memberUids.length; i++) {
  _rosterCoordinator.sendJoinNotification(memberUids[i].toString());
  }
  }

 return teamId;
 } on PostgrestException catch (e) {
 if (e.code == '23505' || e.message.contains('unique') || e.message.contains('duplicate')) {
 throw Exception("اسم الفريق مستخدم بالفعل، يرجى اختيار اسم آخر.");
 }
 rethrow;
 } catch (e) {
 debugPrint('Error creating team: $e');
 rethrow;
 }
 }

 Future<Team?> getTeam(String id) async {
 try {
 final response = await _supabase
 .from('teams')
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
 } catch (e) {
 debugPrint('Error getting team: $e');
 return null;
 }
 }

  Future<List<Team>> fetchTeamsDirectly({String? governorate}) async {
    try {
      final response = await _supabase.from('teams').select().limit(50);
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
    // 1. Immediate REST fetch
    final direct = await fetchTeamsDirectly(governorate: governorate);
    if (direct.isNotEmpty) yield direct;

    // 2. Realtime Stream with safety timeout & error recovery
    yield* _supabase
        .from('teams')
        .stream(primaryKey: ['id'])
        .map((list) {
          return list.map((data) {
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
            return Team.fromFirestore(data, data['id'].toString());
          }).whereType<Team>().toList();
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) async {
            final refreshed = await fetchTeamsDirectly(governorate: governorate);
            sink.add(refreshed);
          },
        )
        .handleError((error) {
          debugPrint('Handled realtime error in getTeams: $error');
        });
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

 Future<Team?> getTeamByCaptainPhone(String phone) async {
 try {
 final response = await _supabase
 .from('teams')
 .select()
 .eq('captain_phone', phone)
 .maybeSingle();
 if (response == null) return null;
 
 final teamId = response['id'].toString();
 return await getTeam(teamId);
 } catch (e) {
 return null;
 }
 }

  Future<void> addMemberToTeam(String teamId, String userId, String imageUrl) =>
      _rosterCoordinator.addMemberToTeam(teamId, userId, imageUrl);

  Future<void> removeMemberFromTeam(String teamId, String userId, String imageUrl) =>
      _rosterCoordinator.removeMemberFromTeam(teamId, userId, imageUrl);

 Future<bool> updateTeam(String teamId, Map<String, dynamic> data) async {
  try {
  final pgData = TeamPayloadBuilder.buildUpdatePayload(data);

 if (pgData.isEmpty) return true;

 await _supabase.from('teams').update(pgData).eq('id', teamId);
 return true;
 } catch (e) {
 debugPrint('Error updating team: $e');
 return false;
 }
 }

 Future<bool> deleteTeam(String teamId) async {
 try {
 final champs = await _supabase
 .from('championships')
 .select('id')
 .contains('joined_teams', [teamId])
 .inFilter('status', ['open', 'ongoing']);
 if ((champs as List).isNotEmpty) throw Exception('team_in_tournament');

 final bookings1 = await _supabase
 .from('bookings')
 .select('end_time')
 .eq('status', 'confirmed')
 .eq('player_team_id', teamId);

 final bookings2 = await _supabase
 .from('bookings')
 .select('end_time')
 .eq('status', 'confirmed')
 .eq('opponent_team_id', teamId);

 bool hasActiveMatch = false;
 for (var doc in [...bookings1 as List, ...bookings2 as List]) {
 final endTime = DateTime.parse(doc['end_time']);
 if (endTime.isAfter(DateTime.now())) {
 hasActiveMatch = true;
 break;
 }
 }

 if (hasActiveMatch) {
 throw Exception('active_match_or_tournament_error');
 }

 await _supabase.from('team_members').delete().eq('team_id', teamId);
 await _supabase.from('teams').delete().eq('id', teamId);
 return true;
 } catch (e) {
 rethrow;
 }
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

  /// Stream single team updates
  Stream<List<Map<String, dynamic>>> streamTeam(String teamId) {
    return _supabase
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
}
