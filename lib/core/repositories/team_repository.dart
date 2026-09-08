import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../constants/egypt_governorates.dart';
import '../repositories/notification_repository.dart';
import '../services/logger_service.dart';
import '../utils/phone_utils.dart';
import 'team/team_payload_builder.dart';

class TeamRepository {
 final SupabaseClient _supabase = Supabase.instance.client;

 Future<List<String>> getTeamMemberUids(String teamId) async {
 final response = await _supabase
 .from('team_members')
 .select('user_id')
 .eq('team_id', teamId);
 return (response as List).map((row) => row['user_id'].toString()).toList();
 }

 Future<List<String>> getTeamPlayerImages(List<String> memberUids) async {
 if (memberUids.isEmpty) return [];
 final response = await _supabase
 .from('users')
 .select('profile_image_url')
 .inFilter('id', memberUids);
 return (response as List)
 .map((row) => row['profile_image_url']?.toString() ?? '')
 .toList();
 }

 /// Fetch list of player profiles (id, name, phone, position) for members of a team
 Future<List<Map<String, String>>> getTeamMemberProfiles(String teamId) async {
 try {
 final memberUids = await getTeamMemberUids(teamId);
 if (memberUids.isEmpty) return [];

 final response = await _supabase
 .from('users')
 .select('id, name, phone, position')
 .inFilter('id', memberUids);

 return (response as List).map((row) => {
 'uid': row['id']?.toString() ?? '',
 'name': row['name']?.toString() ?? 'Player',
 'phone': row['phone']?.toString() ?? '',
 'position': row['position']?.toString() ?? 'Player',
 }).toList();
 } catch (e) {
 debugPrint('Error getting team member profiles: $e');
 return [];
 }
 }

 /// خوارزمية كشف الفرق الوهمية (Fake Team Protection)
 /// الفريق يصبح رسمياً ويؤثر في نقاط الـ Elo والترتيب إذا:
 /// 1. خاض مباراة واحدة موثقة سابقة على الأقل.
 /// 2. ألكابتن والأعضاء لديهم أرقام هواتف موثقة ومختلفة (5+ أعضاء).
 Future<bool> checkIsTeamOfficial(String teamId) async {
 try {
 final team = await getTeam(teamId);
 if (team == null) return false;

 // أ. إذا كان للفريق تاريخ مباريات موثقة سابقة
 if (team.matchesPlayed > 0) {
 return true;
 }

 // ب. التثبت من وجود 5 أعضاء على الأقل بأرقام هواتف موثقة ومختلفة باستخدام captainId الفريق
 final memberUids = await getTeamMemberUids(teamId);
 final captainId = team.captainId.isNotEmpty ? team.captainId : (memberUids.isNotEmpty ? memberUids.first : '');
 if (captainId.isEmpty) return false;

 final allUids = memberUids.contains(captainId) ? memberUids : [captainId, ...memberUids];
 if (allUids.length < 5) return false;

 final response = await _supabase
 .from('users')
 .select('phone')
 .inFilter('id', allUids);

 final phones = (response as List)
 .map((row) => PhoneUtils.normalize(row['phone']?.toString()))
 .where((p) => p != null && p.isNotEmpty)
 .cast<String>()
 .toSet();

 // يجب وجود 5 أرقام هواتف فريدة ومختلفة
 return phones.length >= 5;
 } catch (e) {
 debugPrint('Error checking team official status: $e');
 return false;
 }
 }

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
 final List<Map<String, dynamic>> memberRows = memberUids.map((uid) => {
 'team_id': teamId,
 'user_id': uid.toString(),
 }).toList();
 await _supabase.from('team_members').insert(memberRows);
 }

 if (memberUids.length > 1) {
 for (int i = 1; i < memberUids.length; i++) {
 _sendJoinNotification(memberUids[i].toString());
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

 Future<List<Team>> searchOpponentTeams(String query) async {
 try {
 final response = await _supabase
 .from('teams')
 .select('*, team_members(user_id, users(profile_image_url))')
 .or('name.ilike.%$query%,captain_phone.ilike.%$query%');
 
 final List<Team> teams = [];
 for (final doc in (response as List)) {
 final teamId = doc['id'].toString();
 final membersList = doc['team_members'] as List? ?? [];
 final List<String> memberUids = [];
 final List<String> playerImages = [];
 
 for (var m in membersList) {
 final uid = m['user_id']?.toString();
 if (uid != null) memberUids.add(uid);
 final userMap = m['users'];
 if (userMap is Map && userMap['profile_image_url'] != null) {
 playerImages.add(userMap['profile_image_url'].toString());
 }
 }
 
 final data = Map<String, dynamic>.from(doc);
 data['memberUids'] = memberUids;
 data['playerImages'] = playerImages;
 data['playersCount'] = memberUids.length;
 
 teams.add(Team.fromFirestore(data, teamId));
 }
 return teams;
 } catch (e) {
 return [];
 }
 }

 Future<List<Team>> getPreviousOpponents(String teamId) async {
 try {
 final team = await getTeam(teamId);
 if (team == null || team.playedOpponents.isEmpty) return [];
 
 final response = await _supabase
 .from('teams')
 .select('*, team_members(user_id, users(profile_image_url))')
 .inFilter('id', team.playedOpponents);
 
 final List<Team> teams = [];
 for (final doc in (response as List)) {
 final id = doc['id'].toString();
 final membersList = doc['team_members'] as List? ?? [];
 final List<String> memberUids = [];
 final List<String> playerImages = [];
 
 for (var m in membersList) {
 final uid = m['user_id']?.toString();
 if (uid != null) memberUids.add(uid);
 final userMap = m['users'];
 if (userMap is Map && userMap['profile_image_url'] != null) {
 playerImages.add(userMap['profile_image_url'].toString());
 }
 }
 
 final data = Map<String, dynamic>.from(doc);
 data['memberUids'] = memberUids;
 data['playerImages'] = playerImages;
 data['playersCount'] = memberUids.length;
 
 teams.add(Team.fromFirestore(data, id));
 }
 return teams;
 } catch (e) {
 return [];
 }
 }

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

 Future<void> addMemberToTeam(String teamId, String userId, String imageUrl) async {
 try {
 final memberUids = await getTeamMemberUids(teamId);
 if (memberUids.length >= 12) {
 throw Exception("تنبيه: عذراً، اكتمل الحد الأقصى لأعضاء الفريق (12 لاعباً كحد أقصى).");
 }

 final userTeamMemberships = await _supabase
 .from('team_members')
 .select('team_id')
 .eq('user_id', userId);
 if ((userTeamMemberships as List).length >= 3) {
 throw Exception("تنبيه: اللاعب وصل للحد الأقصى للانضمام للفرق (3 فرق كحد أقصى).");
 }

 await _supabase.from('team_members').insert({
 'team_id': teamId,
 'user_id': userId,
 });
 _sendJoinNotification(userId);
 } on PostgrestException catch (e) {
 if (e.message.contains('الحد الأقصى') || e.message.contains('limit') || e.message.contains('12')) {
 throw Exception("تنبيه: اللاعب وصل للحد الأقصى للانضمام للفرق (3 فرق كحد أقصى) أو الفريق اكتمال (12 لاعباً).");
 }
 rethrow;
 } catch (e) {
 debugPrint('Error adding member to team: $e');
 rethrow;
 }
 }

  Future<void> removeMemberFromTeam(String teamId, String userId, String imageUrl) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final activeBookings = await _supabase
          .from('bookings')
          .select('id')
          .eq('status', 'confirmed')
          .or('player_team_id.eq.$teamId,opponent_team_id.eq.$teamId')
          .gt('end_time', nowIso)
          .limit(1);

      final bool hasActiveMatch = (activeBookings as List).isNotEmpty;

      final activeTournaments = await _supabase
          .from('championships')
          .select('id')
          .inFilter('status', ['open', 'ongoing'])
          .contains('joined_teams', [teamId]);
      final bool hasActiveTournament = (activeTournaments as List).isNotEmpty;
      
      if (hasActiveMatch || hasActiveTournament) {
        throw Exception("active_match_or_tournament_error");
      }

      // Automatic Captain Transfer: If the departing user is the captain, transfer to next member
      final teamData = await _supabase
          .from('teams')
          .select('captain_id')
          .eq('id', teamId)
          .maybeSingle();

      final String currentCaptainId = teamData?['captain_id']?.toString() ?? '';
      if (currentCaptainId == userId) {
        final allMembers = await getTeamMemberUids(teamId);
        final remainingMembers = allMembers.where((uid) => uid != userId).toList();

        if (remainingMembers.isNotEmpty) {
          final nextCaptainId = remainingMembers.first;
          final nextCaptainUser = await _supabase
              .from('users')
              .select('name, phone, profile_image_url')
              .eq('id', nextCaptainId)
              .maybeSingle();

          await _supabase.from('teams').update({
            'captain_id': nextCaptainId,
            'captain_name': nextCaptainUser?['name'] ?? 'Captain',
            'captain_phone': PhoneUtils.normalize(nextCaptainUser?['phone']?.toString() ?? ''),
            'captain_image_url': nextCaptainUser?['profile_image_url'] ?? '',
          }).eq('id', teamId);
        }
      }

      await _supabase
          .from('team_members')
          .delete()
          .eq('team_id', teamId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error removing member from team: $e');
      rethrow;
    }
  }

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

  Future<void> _sendJoinNotification(String userId) async {
    try {
      await NotificationRepository().sendNotification(
        userId,
        AppNotification(
          id: '',
          title: " New Team Transfer!",
          body: "You have been drafted to join a new team. Get ready for the next match!",
          type: "info",
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('Error sending join notification: $e');
    }
  }

  /// Stream user's membership changes
  Stream<List<Map<String, dynamic>>> streamUserMembership(String userId) {
    return _supabase
        .from('team_members')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) => sink.add([]),
        )
        .handleError((err) {
          VSPLogger.w('Membership realtime stream notice: $err');
        });
  }

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
