import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../services/logger_service.dart';
import '../repositories/notification_repository.dart';
import '../repositories/team_repository.dart';
import '../utils/app_date_formatter.dart';
import '../constants/egypt_governorates.dart';
import '../services/notification_handler.dart';
import '../../data/models.dart';
import 'tournament/tournament_payload_builder.dart';
import 'tournament/tournament_bracket_engine.dart';

class TournamentRepository {
 final SupabaseClient _supabase = Supabase.instance.client;

 // ==================== CHAMPIONSHIPS ====================
 
 // Get all championships
 // SECURITY: For players (isOwner=false), only show championships where is_approved=true.
 // Championships become approved automatically when the owner's stadium gets verified by admin.
 // Owners can always see their own championships regardless of approval status.
 Stream<List<Championship>> getChampionshipsStream({
 String? governorate, 
 String? sportType,
 bool isOwner = false,
 String? ownerId,
 }) async* {
    // 1. Emit immediate results via REST API query with DB-level filtering
    try {
      final List<dynamic> response;
      if (isOwner && ownerId != null) {
        response = await _supabase
            .from('championships')
            .select()
            .eq('owner_id', ownerId)
            .order('created_at', ascending: false)
            .limit(50);
      } else {
        response = await _supabase
            .from('championships')
            .select()
            .eq('is_approved', true)
            .order('created_at', ascending: false)
            .limit(50);
      }
 final items = _parseChampionshipsList(
 response,
 governorate: governorate,
 sportType: sportType,
 isOwner: isOwner,
 ownerId: ownerId,
 );
 yield items;
 } catch (e, s) {
 VSPLogger.e('Error fetching initial championships via REST', e, s);
 }

 // 2. Listen to Real-time Stream for updates with filter and timeout safety
    try {
      dynamic streamQuery = _supabase.from('championships').stream(primaryKey: ['id']);
      if (isOwner && ownerId != null) {
        streamQuery = streamQuery.eq('owner_id', ownerId);
      } else if (!isOwner) {
        streamQuery = streamQuery.eq('is_approved', true);
      }

      yield* streamQuery
          .timeout(
            const Duration(seconds: 10),
            onTimeout: (sink) {
              VSPLogger.w('Championships realtime stream timed out. Relying on REST query.');
            },
          )
          .map<List<Championship>>((list) {
            return _parseChampionshipsList(
              list as List<Map<String, dynamic>>,
              governorate: governorate,
              sportType: sportType,
              isOwner: isOwner,
              ownerId: ownerId,
            );
          })
          .handleError((error) {
            VSPLogger.w('Handled realtime stream error in getChampionshipsStream: $error');
          });
    } catch (e, s) {
      VSPLogger.e('Error listening to championships stream', e, s);
    }
 }

 Future<Championship?> getChampionshipById(String id) async {
 try {
 final data = await _supabase.from('championships').select().eq('id', id).maybeSingle();
 if (data == null) return null;
 return Championship.fromFirestore(data, data['id'].toString());
 } catch (e, s) {
 VSPLogger.e('Error fetching championship by id', e, s);
 return null;
 }
 }

  List<Championship> _parseChampionshipsList(
    List<dynamic> list, {
    String? governorate,
    String? sportType,
    bool isOwner = false,
    String? ownerId,
  }) {
    return list.map((data) {
      if (data is! Map<String, dynamic>) return null;
      if (!isOwner) {
        final dynamic approvedVal = data['is_approved'] ?? data['isApproved'];
        if (approvedVal != true) return null;
      }
      // Show all championships from DB as-is
      if (isOwner && ownerId != null) {
        final String champOwnerId = (data['owner_id'] ?? data['ownerId'] ?? '').toString();
        if (champOwnerId != ownerId) return null;
      }
      if (governorate != null &&
          governorate.isNotEmpty &&
          governorate != 'All' &&
          governorate != 'الكل' &&
          governorate != 'الجميع') {
        final String champGov = data['governorate']?.toString() ?? '';
        if (champGov.isNotEmpty) {
          final stdGov1 = EgyptGovernorates.resolveGoogleName(governorate) ?? governorate.trim().toLowerCase();
          final stdGov2 = EgyptGovernorates.resolveGoogleName(champGov) ?? champGov.trim().toLowerCase();
          if (stdGov1 != stdGov2) {
            return null;
          }
        }
      }
      if (sportType != null &&
          sportType.isNotEmpty &&
          sportType != 'All' &&
          sportType != 'الكل' &&
          sportType != 'الجميع') {
        final String champSport = (data['sport_type'] ?? data['sportType'] ?? 'Football').toString();
        if (champSport.isNotEmpty && champSport.toLowerCase() != sportType.toLowerCase()) {
          return null;
        }
      }
      try {
        return Championship.fromFirestore(data, data['id'].toString());
      } catch (e) {
        debugPrint('Error parsing championship: $e');
        return null;
      }
    }).whereType<Championship>().toList();
  }

  Future<String?> createChampionship(Map<String, dynamic> data) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      bool isApproved = false;
      if (currentUserId != null) {
        try {
          final userDoc = await _supabase
              .from('users')
              .select('role')
              .eq('id', currentUserId)
              .maybeSingle();
          final userRole = userDoc?['role']?.toString().toLowerCase();
          if (userRole == 'admin' ||
              userRole == 'co_founder' ||
              userRole == 'super_admin' ||
              userRole == 'cofounder') {
            isApproved = true;
          }
        } catch (_) {
          isApproved = false;
        }
      }

      // Delegate all payload mapping to the pure builder
      final pgData = TournamentPayloadBuilder.buildCreatePayload(
        data,
        isAdminApproved: isApproved,
        fallbackOwnerId: currentUserId ?? '',
      );

      try {
        final response = await _supabase
            .from('championships')
            .insert(pgData)
            .select('id')
            .single();
        return response['id']?.toString();
      } on PostgrestException catch (pe) {
        if (pe.message.contains('championships_type_check')) {
          pgData['type'] = 'Cup';
          final response = await _supabase
              .from('championships')
              .insert(pgData)
              .select('id')
              .single();
          return response['id']?.toString();
        }
        rethrow;
      }
    } catch (e, stack) {
      VSPLogger.e('Error creating championship', e, stack);
      rethrow;
    }
  }

  /// تفعيل ونشر البطولة للمالك (مجانية 100% بدون أي رسوم إنشاء)
  Future<bool> activateChampionship(String championshipId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      bool isApproved = false;
      if (currentUserId != null) {
        try {
          final userDoc = await _supabase
              .from('users')
              .select('role')
              .eq('id', currentUserId)
              .maybeSingle();
          final userRole = userDoc?['role']?.toString().toLowerCase();
          if (userRole == 'admin' ||
              userRole == 'co_founder' ||
              userRole == 'super_admin' ||
              userRole == 'cofounder') {
            isApproved = true;
          }
        } catch (_) {}
      }

      final updateMap = <String, dynamic>{
        'status': 'open',
        'creation_fee_paid': true,
      };
      if (isApproved) {
        updateMap['is_approved'] = true;
      }
      await _supabase.from('championships').update(updateMap).eq('id', championshipId);
      VSPLogger.i('Championship $championshipId activated successfully.');
      return true;
    } catch (e, stack) {
      VSPLogger.e('Error activating championship', e, stack);
      return false;
    }
  }

 Future<bool> updateChampionship(String id, Map<String, dynamic> data) async {
  try {
   // Delegate all payload mapping to the pure builder
   final pgData = TournamentPayloadBuilder.buildUpdatePayload(data);
   if (pgData.isEmpty) return true;

   await _supabase
    .from('championships')
    .update(pgData)
    .eq('id', id);
   return true;
  } catch (e) {
   debugPrint('Error updating championship: $e');
   return false;
  }
 }

 Future<bool> joinChampionship(
 String championshipId, 
 String teamId, {
 List<String> selectedPlayerIds = const [],
 List<String> offlineGuestNames = const [],
 bool skipMemberCheck = false,
 bool isPaid = false,
 double? totalPaidAmount,
 }) async {
 try {
 final team = await TeamRepository().getTeam(teamId);
 if (team == null) throw Exception('المجموعة لا توجد.');

 final champResponse = await _supabase
 .from('championships')
 .select()
 .eq('id', championshipId)
 .maybeSingle();
 if (champResponse == null) throw Exception('البطولة لا توجد.');

 final champ = Championship.fromFirestore(champResponse, championshipId);

 if (!skipMemberCheck) {
 final totalRoster = selectedPlayerIds.length + offlineGuestNames.length;
 if (totalRoster < champ.minPlayersPerTeam) {
 throw Exception('يجب أن تضم تشكيلة الفريق ${champ.minPlayersPerTeam} لاعبين على الأقل للمشاركة.');
 }
 if (totalRoster > champ.maxPlayersPerTeam) {
 throw Exception('تجاوزت تشكيلة الفريق الحد الأقصى للاعبين (${champ.maxPlayersPerTeam}).');
 }
 }

 // استخدام الدالة الذرية الموثقة في السيرفر لتجاوز قيد RLS
 final rpcRes = await _supabase.rpc('join_championship_atomic', params: {
 'p_championship_id': championshipId,
 'p_team_id': teamId,
 'p_is_paid': isPaid,
 });

 if (rpcRes is Map && rpcRes['success'] == false) {
 throw Exception(rpcRes['message']?.toString() ?? 'فشل الانضمام للبطولة.');
 }

 // حفظ تشكيلة الفريق
 try {
 await updateSingleTeamRoster(
 championshipId: championshipId,
 teamId: teamId,
 playerIds: selectedPlayerIds,
 guestNames: offlineGuestNames,
 );
 } catch (rosterErr) {
 debugPrint(' Roster sync notice: $rosterErr');
 }

 // إشعار مالك البطولة
 if (champ.ownerId.isNotEmpty) {
 try {
 await NotificationHandler.notifyTeamJoinedTournament(
 ownerId: champ.ownerId,
 teamName: team.name,
 tournamentName: champ.name,
 championshipId: championshipId,
 );
 } catch (_) {}
 }

 return true;
 } catch (e) {
 debugPrint('Error joining championship: $e');
 rethrow;
 }
 }

 /// إنشاء طلب سداد بطولة مسبق في قاعدة البيانات
 Future<Map<String, dynamic>?> createTournamentOrder({
 required String championshipId,
 required String teamId,
 required double amount,
 List<String> playerIds = const [],
 List<String> guestNames = const [],
 }) async {
 try {
 final res = await _supabase.rpc('create_tournament_order_atomic', params: {
 'p_championship_id': championshipId,
 'p_team_id': teamId,
 'p_player_ids': playerIds,
 'p_guest_names': guestNames,
 'p_amount': amount,
 });
 if (res is Map && res['success'] == true) {
 return Map<String, dynamic>.from(res);
 }
 return null;
 } catch (e) {
 debugPrint('Error creating tournament order: $e');
 return null;
 }
 }

 /// تأكيد سداد البطولة برقم المرجع ومعاملة Paymob
 Future<bool> confirmTournamentOrder({
 required String orderReference,
 required String paymobTransactionId,
 }) async {
 try {
 final res = await _supabase.rpc('confirm_tournament_order_atomic', params: {
 'p_order_reference': orderReference,
 'p_paymob_transaction_id': paymobTransactionId,
 });
 if (res is Map && res['success'] == true) {
 return true;
 }
 return false;
 } catch (e) {
 debugPrint('Error confirming tournament order: $e');
 return false;
 }
 }

 // TOURNAMENT Logic: Update championship status
 Future<void> updateChampionshipStatus(String championshipId, String status) async {
 try {
 await _supabase
 .from('championships')
 .update({'status': status})
 .eq('id', championshipId);
 } catch (e) {
 debugPrint('Error updating championship status: $e');
 }
 }

 Future<void> crownChampion(String championshipId, String winningTeamId, String winningTeamName) async {
 try {
 // 1. Mark championship as completed
 await _supabase
 .from('championships')
 .update({
 'status': 'completed',
 'champion_team_id': winningTeamId,
 'champion_team_name': winningTeamName,
 })
 .eq('id', championshipId);

 // 2. Increment team's trophies and add badge
 final team = await TeamRepository().getTeam(winningTeamId);
 if (team != null) {
 final badges = List<String>.from(team.unlockedBadges);
 if (!badges.contains('cup_winner')) {
 badges.add('cup_winner');
 }
 await _supabase
 .from('teams')
 .update({
 'championships_won': team.championshipsWon + 1,
 'unlocked_badges': badges,
 })
 .eq('id', winningTeamId);
 }

 // 3. ── Celebration Notifications ──
 await _sendCelebrationNotifications(winningTeamId);
 } catch (e) {
 debugPrint('Error crowning champion: $e');
 throw 'Failed to crown champion';
 }
 }

 Future<void> _sendCelebrationNotifications(String teamId) async {
 try {
 final team = await TeamRepository().getTeam(teamId);
 if (team == null) return;

 for (final uid in team.memberUids) {
 await NotificationRepository().sendNotification(
 uid,
 AppNotification(
 id: '',
 title: " CHAMPIONS!",
 body: "Your team has won the championship! A new trophy has been added to your team profile.",
 type: "info",
 createdAt: DateTime.now(),
 ),
 );
 }
 } catch (e) {
 debugPrint('Error sending celebration notifications: $e');
 }
 }

 // TOURNAMENT Logic: Fetch joined teams for dashboard
 Future<List<Team>> getTeamsByIds(List<String> ids) async {
 if (ids.isEmpty) return [];
 try {
 // PERF-FIX: استخدام JOIN (العلاقات المدمجة) لجلب جميع البيانات في طلب HTTP واحد فقط بدلاً من 65 طلب!
 final response = await _supabase
 .from('teams')
 .select('*, team_members(user_id, users(profile_image_url))')
 .inFilter('id', ids);
 
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
 debugPrint('Error getting teams by IDs: $e');
 return [];
 }
 }

 // ==================== TOURNAMENT BRACKET ENGINE ====================

  Future<void> generateFixtures(String championshipId) async {
    try {
      // 1. First attempt atomic server-side generation
      try {
        final rpcRes = await _supabase.rpc('generate_tournament_bracket_atomic', params: {'p_championship_id': championshipId});
        if (rpcRes is Map && rpcRes['success'] == true) {
          VSPLogger.i('Tournament Fixtures generated via atomic server function: $rpcRes');
          _sendDrawNotifications(championshipId);
          return;
        }
      } catch (atomicErr) {
        VSPLogger.w('generate_tournament_bracket_atomic fallback to client generator: $atomicErr');
      }

      final champDoc = await _supabase
          .from('championships')
          .select()
          .eq('id', championshipId)
          .maybeSingle();
      if (champDoc == null) throw Exception('البطولة لا توجد.');

      final bool isPaidTourney = (champDoc['entry_fee'] != null && (champDoc['entry_fee'] as num) > 0);
      final List<String> teamIds = isPaidTourney
          ? List<String>.from(champDoc['paid_teams'] ?? [])
          : List<String>.from(champDoc['joined_teams'] ?? champDoc['joinedTeams'] ?? []);
      final int totalTeams = teamIds.length;
      if (totalTeams < 2) {
        throw Exception(isPaidTourney
            ? 'يجب وجود فريقين مسددين لرسوم الاشتراك على الأقل لبدء البطولة.'
            : 'يجب وجود فريقين على الأقل لبدء البطولة.');
      }

      final String? rawStartDate = champDoc['start_date'] ?? champDoc['startDate'];
      if (rawStartDate != null) {
        final startDate = DateTime.parse(rawStartDate);
        if (DateTime.now().isBefore(startDate)) {
          final formattedDate = AppDateFormatter.formatFullDate(startDate, 'ar');
          throw Exception('لا يمكن بدء البطولة أو إطلاق القرعة قبل الموعد المعلن للفرق ($formattedDate) لالتزام اللاعبين واستعدادهم.');
        }
      }

      final int configuredMaxTeams = champDoc['max_teams'] ?? champDoc['maxTeams'] ?? 16;
      final int bracketCapacity = TournamentBracketEngine.computeBracketCapacity(
        totalTeams, configuredMaxTeams,
      );

      final teams = await getTeamsByIds(teamIds);
      final teamMap = {for (var t in teams) t.id: t.name};

      final shuffledIds = List<String>.from(teamIds)..shuffle(Random());
      final List<String?> slots = List.generate(bracketCapacity, (index) {
        return index < shuffledIds.length ? shuffledIds[index] : null;
      });

      // Delegate all bracket computation to the pure engine
      final allMatchesToInsert = TournamentBracketEngine.buildKnockoutMatchList(
        championshipId: championshipId,
        bracketCapacity: bracketCapacity,
        slots: slots,
        teamMap: teamMap,
      );
 if (allMatchesToInsert.isNotEmpty) {
 await _supabase.from('tournament_matches').insert(allMatchesToInsert);
 }

 await _supabase
 .from('championships')
 .update({'status': 'ongoing'})
 .eq('id', championshipId);

 _sendDrawNotifications(championshipId);

 debugPrint(' Tournament Fixtures generated successfully with BYE logic for $championshipId ($totalTeams teams)');
 } catch (e) {
 debugPrint('Error generating fixtures: $e');
 rethrow;
 }
 }

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

 final String? nextMatchId = response['next_match_id'] ?? response['nextMatchId'];
 final int matchIndex = response['match_index'] ?? response['matchIndex'] ?? 0;
 final String championshipId = response['championship_id'] ?? response['championshipId'] ?? '';

 bool rpcHandled = false;
 try {
 final rpcRes = await _supabase.rpc('record_match_result_and_advance_atomic', params: {
 'p_match_id': matchId,
 'p_home_score': homeScore,
 'p_away_score': awayScore,
 'p_home_penalties': homePenalties,
 'p_away_penalties': awayPenalties,
 'p_winner_id': winnerId,
 'p_winner_name': winnerName,
 'p_goal_details': goalDetails.map((g) => g.toMap()).toList(),
 });
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
 String slotField = (matchIndex % 2 == 0) ? 'home' : 'away';

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
 } else {
 // ── Final Match: Crown the Champion ──
 if (winnerId != null) {
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
 await _supabase.rpc('crown_tournament_champion_atomic', params: {
 'p_championship_id': championshipId,
 'p_champion_team_id': winnerId,
 'p_champion_team_name': winnerName ?? '',
 });
 } catch (rpcErr) {
 debugPrint('crown_tournament_champion_atomic fallback: $rpcErr');
 await _supabase
 .from('championships')
 .update({
 'status': 'completed',
 'champion_team_id': winnerId,
 'champion_team_name': winnerName,
 })
 .eq('id', championshipId);

 final team = await TeamRepository().getTeam(winnerId);
 if (team != null) {
 final badges = List<String>.from(team.unlockedBadges);
 if (!badges.contains('cup_winner')) {
 badges.add('cup_winner');
 }
 await _supabase
 .from('teams')
 .update({
 'championships_won': team.championshipsWon + 1,
 'unlocked_badges': badges,
 })
 .eq('id', winnerId);
 }
 }

 // ── Celebration Notifications (Final Match) ──
 await _sendCelebrationNotifications(winnerId);
 }
 }
 } catch (e) {
 debugPrint('Error updating tournament match score: $e');
 rethrow;
 }
 }

 /// Update the scheduled time for a tournament match
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

 /// Toggle a team's paid status in a championship
 Future<void> toggleTeamPayment({
 required String championshipId,
 required String teamId,
 required bool isPaid,
 }) async {
 try {
 final response = await _supabase
 .from('championships')
 .select('paid_teams')
 .eq('id', championshipId)
 .maybeSingle();
 if (response == null) throw 'Championship not found';

 final paidTeams = List<String>.from(response['paid_teams'] ?? []);
 if (isPaid) {
 if (!paidTeams.contains(teamId)) {
 paidTeams.add(teamId);
 }
 } else {
 paidTeams.remove(teamId);
 }

 await _supabase.from('championships').update({
 'paid_teams': paidTeams,
 }).eq('id', championshipId);
 } catch (e) {
 debugPrint('Error toggling team payment: $e');
 rethrow;
 }
 }

  Future<List<TournamentMatch>> getTournamentMatchesDirectly(String championshipId) async {
    try {
      final response = await _supabase
          .from('tournament_matches')
          .select()
          .eq('championship_id', championshipId);
      final matches = (response as List)
          .map((data) => TournamentMatch.fromFirestore(data as Map<String, dynamic>, data['id'].toString()))
          .toList();
      matches.sort((a, b) {
        if (a.roundIndex != b.roundIndex) return b.roundIndex.compareTo(a.roundIndex);
        return a.matchIndex.compareTo(b.matchIndex);
      });
      return matches;
    } catch (e) {
      debugPrint('Error fetching tournament matches directly: $e');
      return [];
    }
  }

  Stream<List<TournamentMatch>> getTournamentMatches(String championshipId) async* {
    // 1. Direct REST fetch for immediate UI display without waiting on Realtime
    final direct = await getTournamentMatchesDirectly(championshipId);
    if (direct.isNotEmpty) yield direct;

    // 2. Realtime stream with safety timeout and error recovery
    yield* _supabase
        .from('tournament_matches')
        .stream(primaryKey: ['id'])
        .map((list) {
          final matches = list
              .map((data) => TournamentMatch.fromFirestore(data, data['id'].toString()))
              .where((m) => m.championshipId == championshipId)
              .toList();
          matches.sort((a, b) {
            if (a.roundIndex != b.roundIndex) return b.roundIndex.compareTo(a.roundIndex);
            return a.matchIndex.compareTo(b.matchIndex);
          });
          return matches;
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) async {
            final refreshed = await getTournamentMatchesDirectly(championshipId);
            sink.add(refreshed);
          },
        )
        .handleError((error) {
          debugPrint('Handled realtime error in getTournamentMatches: $error');
        });
  }

 /// انسحاب الفريق الذري من البطولة (Atomic Tournament Withdrawal)
 Future<bool> leaveChampionship(String championshipId, String teamId) async {
 try {
 try {
 await _supabase.rpc('leave_championship_atomic', params: {
 'p_championship_id': championshipId,
 'p_team_id': teamId,
 });
 debugPrint(' Team $teamId left championship $championshipId via leave_championship_atomic RPC.');
 return true;
 } catch (rpcErr) {
 debugPrint(' leave_championship_atomic RPC fallback notice: $rpcErr');
 final champDoc = await _supabase
 .from('championships')
 .select('joined_teams, paid_teams, status')
 .eq('id', championshipId)
 .maybeSingle();

 if (champDoc != null) {
 final String status = (champDoc['status'] ?? 'open').toString();
 if (status == 'ongoing' || status == 'completed') {
 throw Exception('لا يمكن الانسحاب من بطولة جارية أو مكتملة.');
 }

 final joinedTeams = List<String>.from(champDoc['joined_teams'] ?? [])..remove(teamId);
 final paidTeams = List<String>.from(champDoc['paid_teams'] ?? [])..remove(teamId);

 await _supabase.from('championships').update({
 'joined_teams': joinedTeams,
 'paid_teams': paidTeams,
 }).eq('id', championshipId);

 try {
 await _supabase.from('championship_rosters').delete().eq('championship_id', championshipId).eq('team_id', teamId);
 } catch (_) {}

 return true;
 }
 return false;
 }
 } catch (e) {
 debugPrint(' Error in leaveChampionship: $e');
 return false;
 }
 }

 Future<bool> removeTournamentTeam(String championshipId, String teamId) async {
 try {
 try {
 await _supabase.rpc('remove_tournament_team_atomic', params: {
 'p_championship_id': championshipId,
 'p_team_id': teamId,
 });
 debugPrint(' Team $teamId removed via remove_tournament_team_atomic RPC.');
 return true;
 } catch (rpcErr) {
 debugPrint(' remove_tournament_team_atomic fallback: $rpcErr');
 return await leaveChampionship(championshipId, teamId);
 }
 } catch (e) {
 debugPrint(' Error in removeTournamentTeam: $e');
 return false;
 }
 }

 Future<void> _sendDrawNotifications(String championshipId) async {
 try {
 final champ = await _supabase
 .from('championships')
 .select('name')
 .eq('id', championshipId)
 .maybeSingle();
 if (champ == null) return;
 final champName = champ['name']?.toString() ?? 'البطولة';

 final response = await _supabase
 .from('tournament_matches')
 .select('home_team_id, away_team_id, home_team_name, away_team_name')
 .eq('championship_id', championshipId);
 
 final matchesList = response as List;
 final Set<String> teamIds = {};
 for (final m in matchesList) {
 if (m['home_team_id'] != null) teamIds.add(m['home_team_id'].toString());
 if (m['away_team_id'] != null) teamIds.add(m['away_team_id'].toString());
 }

 if (teamIds.isEmpty) return;

 // جلب بيانات جميع الفرق دفعة واحدة (Batching)
 final allTeams = await getTeamsByIds(teamIds.toList());
 final Map<String, Team> teamMap = {for (var t in allTeams) t.id: t};

 final List<Map<String, dynamic>> notificationsToInsert = [];

 for (final matchData in matchesList) {
 final String? homeId = matchData['home_team_id']?.toString();
 final String? awayId = matchData['away_team_id']?.toString();
 final String homeName = matchData['home_team_name']?.toString() ?? '';
 final String awayName = matchData['away_team_name']?.toString() ?? '';

 if (homeId != null && awayId != null) {
 final homeTeam = teamMap[homeId];
 if (homeTeam != null) {
 for (final uid in homeTeam.memberUids) {
 notificationsToInsert.add({
 'user_id': uid,
 'title': " تم إجراء قرعة البطولة!",
 'body': "فريقك سيواجه فريق ($awayName) في بطولة ($champName). تفقد جدول المباريات لمعرفة الموعد والتفاصيل!",
 'type': "info",
 'created_at': DateTime.now().toUtc().toIso8601String(),
 'is_read': false,
 });
 }
 }

 final awayTeam = teamMap[awayId];
 if (awayTeam != null) {
 for (final uid in awayTeam.memberUids) {
 notificationsToInsert.add({
 'user_id': uid,
 'title': " تم إجراء قرعة البطولة!",
 'body': "فريقك سيواجه فريق ($homeName) في بطولة ($champName). تفقد جدول المباريات لمعرفة الموعد والتفاصيل!",
 'type': "info",
 'created_at': DateTime.now().toUtc().toIso8601String(),
 'is_read': false,
 });
 }
 }
 }
 }

 if (notificationsToInsert.isNotEmpty) {
 await _supabase.from('notifications').insert(notificationsToInsert);
 }
 } catch (e) {
 debugPrint('Error sending draw notifications: $e');
 }
 }

 /// Fetch player rosters for home and away teams in a championship (registered players + guests)
 Future<Map<String, List<String>>> fetchRosters(String championshipId, String homeTeamId, String awayTeamId) async {
 final homePlayers = await _fetchTeamFullRosterNames(championshipId, homeTeamId);
 final awayPlayers = await _fetchTeamFullRosterNames(championshipId, awayTeamId);
 return {'home': homePlayers, 'away': awayPlayers};
 }

 Future<List<String>> _fetchTeamFullRosterNames(String championshipId, String teamId) async {
 if (teamId.isEmpty) return [];
 final Set<String> names = {};

 try {
 final roster = await _supabase
 .from('championship_rosters')
 .select()
 .eq('championship_id', championshipId)
 .eq('team_id', teamId)
 .maybeSingle();

 if (roster != null) {
 final rosterId = roster['id']?.toString();

 // 1. Guests from championship_rosters flat arrays
 final guestNamesRaw = roster['guest_names'] ?? roster['player_names'] ?? [];
 if (guestNamesRaw is List) {
 for (var g in guestNamesRaw) {
 if (g != null && g.toString().trim().isNotEmpty) {
 names.add(g.toString().trim());
 }
 }
 }

 // 2. Guests from championship_roster_guests table
 if (rosterId != null) {
 try {
 final guestRows = await _supabase
 .from('championship_roster_guests')
 .select('guest_name')
 .eq('roster_id', rosterId);
 for (var row in guestRows) {
 final gName = row['guest_name']?.toString().trim();
 if (gName != null && gName.isNotEmpty) {
 names.add(gName);
 }
 }
 } catch (e) {
 debugPrint('championship_roster_guests notice: $e');
 }
 }

 // 3. Registered players from championship_roster_players joined with users table
 List<String> playerIds = [];
 if (rosterId != null) {
 try {
 final playerRows = await _supabase
 .from('championship_roster_players')
 .select('player_id')
 .eq('roster_id', rosterId);
 for (var row in playerRows) {
 final pId = row['player_id']?.toString();
 if (pId != null && pId.isNotEmpty) {
 playerIds.add(pId);
 }
 }
 } catch (e) {
 debugPrint('championship_roster_players notice: $e');
 }
 }

 if (playerIds.isEmpty) {
 final pIdsRaw = roster['player_ids'];
 if (pIdsRaw is List) {
 playerIds = pIdsRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
 }
 }

 if (playerIds.isNotEmpty) {
 try {
 final userRows = await _supabase
 .from('users')
 .select('name')
 .inFilter('id', playerIds);
 for (var u in userRows) {
 final uName = u['name']?.toString().trim();
 if (uName != null && uName.isNotEmpty) {
 names.add(uName);
 }
 }
 } catch (e) {
 debugPrint('Users fetch notice for roster: $e');
 }
 }
 }
 } catch (e) {
 debugPrint('Error fetching roster for team $teamId: $e');
 }

 // 4. Fallback if roster table is unpopulated: fetch team member names from team_members/users
 if (names.isEmpty && teamId.isNotEmpty) {
 try {
 final uids = await TeamRepository().getTeamMemberUids(teamId);
 if (uids.isNotEmpty) {
 final userRows = await _supabase.from('users').select('name').inFilter('id', uids).limit(uids.length);
 for (var u in userRows) {
 final uName = u['name']?.toString().trim();
 if (uName != null && uName.isNotEmpty) {
 names.add(uName);
 }
 }
 }
 } catch (_) {}
 }

 return names.toList();
 }

 /// Fetch player IDs and guest names for a single team in a championship roster
 Future<Map<String, dynamic>> getSingleTeamRoster(String championshipId, String teamId) async {
 try {
 final roster = await _supabase
 .from('championship_rosters')
 .select()
 .eq('championship_id', championshipId)
 .eq('team_id', teamId)
 .maybeSingle();

 if (roster != null) {
 final rosterId = roster['id'].toString();
 List<String> playerIdsList = [];

 try {
 final playerRows = await _supabase
 .from('championship_roster_players')
 .select('player_id')
 .eq('roster_id', rosterId);
 if (playerRows.isNotEmpty) {
 playerIdsList = playerRows.map((r) => r['player_id'].toString()).toList();
 }
 } catch (_) {}

 if (playerIdsList.isEmpty) {
 final playerIdsRaw = roster['player_ids'] ?? [];
 if (playerIdsRaw is List) {
 playerIdsList = List<String>.from(playerIdsRaw);
 }
 }

 final guestNamesRaw = roster['guest_names'] ?? roster['player_names'] ?? [];

 return {
 'player_ids': playerIdsList,
 'guest_names': guestNamesRaw is List ? List<String>.from(guestNamesRaw) : <String>[],
 };
 }
 } catch (e) {
 debugPrint('Error fetching single team roster: $e');
 }
 return {'player_ids': <String>[], 'guest_names': <String>[]};
 }

 /// Update single team roster (player_ids & guest_names) in a championship
 Future<bool> updateSingleTeamRoster({
 required String championshipId,
 required String teamId,
 required List<String> playerIds,
 required List<String> guestNames,
 }) async {
 try {
 final existing = await _supabase
 .from('championship_rosters')
 .select('id')
 .eq('championship_id', championshipId)
 .eq('team_id', teamId)
 .maybeSingle();

 String rosterId;
 final payload = {
 'championship_id': championshipId,
 'team_id': teamId,
 'guest_names': guestNames,
 };

 if (existing != null) {
 rosterId = existing['id'].toString();
 await _supabase
 .from('championship_rosters')
 .update(payload)
 .eq('id', rosterId);
 } else {
 final inserted = await _supabase
 .from('championship_rosters')
 .insert(payload)
 .select('id')
 .single();
 rosterId = inserted['id'].toString();
 }

 // Separate player_ids into championship_roster_players table
 try {
 await _supabase
 .from('championship_roster_players')
 .delete()
 .eq('roster_id', rosterId);

 if (playerIds.isNotEmpty) {
 final rosterPlayerRows = playerIds.map((pId) => {
 'roster_id': rosterId,
 'player_id': pId,
 }).toList();

 await _supabase
 .from('championship_roster_players')
 .insert(rosterPlayerRows);
 }
 } catch (err) {
 debugPrint(' championship_roster_players sync notice: $err');
 }

 debugPrint(' Tournament roster updated successfully for team $teamId');
 return true;
 } catch (e) {
 debugPrint(' Error updating tournament roster: $e');
 return false;
 }
 }

 /// Auto-schedule matches in a specific round across 1, 2, or 4 days
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
 int totalMatches = matches.length;
 int matchesPerDay = (totalMatches / daysCount).ceil();

 for (int i = 0; i < totalMatches; i++) {
 final match = matches[i];
 int dayOffset = i ~/ matchesPerDay;
 int matchIndexInDay = i % matchesPerDay;

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

 /// Clear/reset all scheduled times for matches in a specific round
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

 /// Get top scorers for a championship aggregated from match goal details
 Future<List<Map<String, dynamic>>> getTopScorersForChampionship(String championshipId) async {
 try {
 final response = await _supabase
 .from('tournament_matches')
 .select('goal_details, home_team_name, away_team_name')
 .eq('championship_id', championshipId)
 .neq('goal_details', '[]')
 .eq('is_completed', true);

 final Map<String, Map<String, dynamic>> scorerStats = {};


 for (final matchData in (response as List)) {
 final rawGoals = matchData['goal_details'] as List?;
 if (rawGoals == null || rawGoals.isEmpty) continue;

 final homeTeamName = matchData['home_team_name']?.toString().trim() ?? '';
 final awayTeamName = matchData['away_team_name']?.toString().trim() ?? '';

 for (final item in rawGoals) {
 if (item is Map) {
 final bool isOwnGoal = item['is_own_goal'] == true || item['isOwnGoal'] == true;
 final playerName = item['player_name']?.toString().trim() ?? item['playerName']?.toString().trim() ?? '';
 
 if (isOwnGoal) {
 continue;
 }

 if (playerName.isEmpty) continue;

 String teamName = item['team_name']?.toString().trim() ?? item['teamName']?.toString().trim() ?? item['team']?.toString().trim() ?? '';
 if (teamName.isEmpty || teamName == 'فريق غير محدد') {
 teamName = homeTeamName.isNotEmpty ? homeTeamName : (awayTeamName.isNotEmpty ? awayTeamName : '');
 }

 final key = '$playerName@$teamName';
 if (!scorerStats.containsKey(key)) {
 scorerStats[key] = {
 'name': playerName,
 'team': teamName,
 'goals': 0,
 'isOwnGoalCategory': false,
 };
 }
 scorerStats[key]!['goals'] = (scorerStats[key]!['goals'] as int) + 1;
 }
 }
 }

 final list = scorerStats.values.toList();
 list.sort((a, b) => (b['goals'] as int).compareTo(a['goals'] as int));

 return list;
 } catch (e) {
 debugPrint('Error getting top scorers: $e');
 return [];
 }
 }

 /// Get clean sheet teams/goalkeepers for a championship directly from database match scores
 Future<List<Map<String, dynamic>>> getCleanSheetsForChampionship(String championshipId) async {
 try {
 final response = await _supabase
 .from('tournament_matches')
 .select('home_score, away_score, home_team_name, away_team_name, status')
 .eq('championship_id', championshipId)
 .eq('status', 'completed');

 final Map<String, int> teamCleanSheets = {};

 for (final matchData in (response as List)) {
 final homeScore = matchData['home_score'] as int?;
 final awayScore = matchData['away_score'] as int?;
 final homeTeam = matchData['home_team_name']?.toString() ?? '';
 final awayTeam = matchData['away_team_name']?.toString() ?? '';

 if (homeScore != null && awayScore != null) {
 if (awayScore == 0 && homeTeam.isNotEmpty) {
 teamCleanSheets[homeTeam] = (teamCleanSheets[homeTeam] ?? 0) + 1;
 }
 if (homeScore == 0 && awayTeam.isNotEmpty) {
 teamCleanSheets[awayTeam] = (teamCleanSheets[awayTeam] ?? 0) + 1;
 }
 }
 }

 final list = teamCleanSheets.entries.map((e) => {
 'team': e.key,
 'clean_sheets': e.value,
 }).toList();

 list.sort((a, b) => (b['clean_sheets'] as int).compareTo(a['clean_sheets'] as int));
 return list;
 } catch (e) {
 debugPrint('Error getting clean sheets: $e');
 return [];
 }
 }

 // ─── 1. جلب جدول ترتيب الدوري أو المجموعات أوتوماتيكياً من Supabase ───
 Future<List<Map<String, dynamic>>> getChampionshipStandings(String championshipId, {String? groupName}) async {
 try {
 final response = await _supabase.rpc('get_championship_standings', params: {
 'p_championship_id': championshipId,
 'p_group_name': groupName,
 });
 return List<Map<String, dynamic>>.from(response as List? ?? []);
 } catch (e) {
 debugPrint('Error fetching standings: $e');
 return [];
 }
 }

 // ─── 2. توليد مباريات الدوري الكامل (Round-Robin Algorithm) ───
 Future<void> generateLeagueFixtures(String championshipId) async {
 try {
 try {
 await _supabase.rpc('prepare_tournament_bracket', params: {'p_championship_id': championshipId});
 } catch (e) {
 debugPrint('prepare_tournament_bracket RPC notice: $e');
 try {
 await _supabase.from('tournament_matches').delete().eq('championship_id', championshipId);
 } catch (_) {}
 }

 final champDoc = await _supabase.from('championships').select().eq('id', championshipId).maybeSingle();
 if (champDoc == null) throw Exception('البطولة غير موجودة');

 final List<String> teamIds = (champDoc['joined_teams'] as List? ?? champDoc['joinedTeams'] as List?)?.map((e) => e.toString()).toList() ?? [];
 if (teamIds.length < 2) throw Exception('يجب وجود فريقين على الأقل لإنشاء الدوري');

 final teams = await getTeamsByIds(teamIds);
 final teamMap = {for (var t in teams) t.id: t.name};
 final isTwoLegs = champDoc['is_two_legs'] == true || champDoc['isTwoLegs'] == true;

 // Delegate league fixture generation to the pure engine
 final matchesToInsert = TournamentBracketEngine.buildLeagueMatchList(
  championshipId: championshipId,
  teamIds: teamIds,
  teamMap: teamMap,
  isTwoLegs: isTwoLegs,
 );

 if (matchesToInsert.isNotEmpty) {
 await _supabase.from('tournament_matches').insert(matchesToInsert);
 }

 await _supabase.from('championships').update({'status': 'ongoing'}).eq('id', championshipId);
 debugPrint(' League Fixtures generated successfully (${matchesToInsert.length} matches)');
 } catch (e) {
 debugPrint('Error generating league fixtures: $e');
 rethrow;
 }
 }

 // ─── 3. توليد مباريات المجموعات ثم التصفيات (Groups + Knockout) ───
 Future<void> generateGroupsFixtures(String championshipId) async {
 try {
 try {
 await _supabase.rpc('prepare_tournament_bracket', params: {'p_championship_id': championshipId});
 } catch (e) {
 debugPrint('prepare_tournament_bracket RPC notice: $e');
 try {
 await _supabase.from('tournament_matches').delete().eq('championship_id', championshipId);
 } catch (_) {}
 }

 final champDoc = await _supabase.from('championships').select().eq('id', championshipId).maybeSingle();
 if (champDoc == null) throw Exception('البطولة غير موجودة');

 final List<String> teamIds = (champDoc['joined_teams'] as List? ?? champDoc['joinedTeams'] as List?)?.map((e) => e.toString()).toList() ?? [];
 final int numGroups = int.tryParse((champDoc['number_of_groups'] ?? champDoc['numberOfGroups'] ?? 2).toString()) ?? 2;

 if (teamIds.length < numGroups * 2) {
 throw Exception('عدد الفرق غير كافٍ لتقسيمهم على $numGroups مجموعات');
 }

 final teams = await getTeamsByIds(teamIds);
 final teamMap = {for (var t in teams) t.id: t.name};

 // Delegate group fixture generation to the pure engine
 final matchesToInsert = TournamentBracketEngine.buildGroupMatchList(
  championshipId: championshipId,
  teamIds: teamIds,
  teamMap: teamMap,
  numGroups: numGroups,
 );

 if (matchesToInsert.isNotEmpty) {
 await _supabase.from('tournament_matches').insert(matchesToInsert);
 }

 await _supabase.from('championships').update({'status': 'ongoing'}).eq('id', championshipId);
 debugPrint(' Group Stage Fixtures generated successfully');
 } catch (e) {
 debugPrint('Error generating groups fixtures: $e');
 rethrow;
 }
 }

 // ─── 4. التصعيد التلقائي من المجموعات إلى شجرة الإقصائيات (Advance Groups to Knockout) ───
 Future<void> advanceGroupsToKnockout(String championshipId) async {
 try {
 final champDoc = await _supabase.from('championships').select().eq('id', championshipId).maybeSingle();
 if (champDoc == null) return;

 final int numGroups = int.tryParse((champDoc['number_of_groups'] ?? champDoc['numberOfGroups'] ?? 2).toString()) ?? 2;
 final int qualifyingPerGroup = int.tryParse((champDoc['qualifying_per_group'] ?? champDoc['qualifyingPerGroup'] ?? 2).toString()) ?? 2;
 final List<String> groupNames = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

 // Map to store qualified teams per group in rank order
 final Map<String, List<Map<String, String>>> groupQualifiersMap = {};
 for (int g = 0; g < numGroups; g++) {
 final groupName = groupNames[g];
 final standings = await getChampionshipStandings(championshipId, groupName: groupName);

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
  final knockoutMatches = TournamentBracketEngine.buildKnockoutFromQualifiedTeams(
   championshipId: championshipId,
   qualifiedTeams: qualifiedTeams,
  );

  if (knockoutMatches.isNotEmpty) {
  await _supabase.from('tournament_matches').insert(knockoutMatches);
  }

     debugPrint(' Successfully advanced group winners to Knockout stage!');
     } catch (e) {
       debugPrint('Error advancing groups to knockout: $e');
       rethrow;
     }
   }

  /// بث مباشر لحظي لتفاصيل بطولة معينة (Realtime Stream with REST Fallback)
  Stream<Championship?> getSingleChampionshipStream(String championshipId) async* {
    // 1. Immediate REST fetch
    try {
      final direct = await getChampionshipById(championshipId);
      if (direct != null) yield direct;
    } catch (_) {}

    // 2. Realtime Stream with safety timeout & error recovery
    yield* _supabase
        .from('championships')
        .stream(primaryKey: ['id'])
        .eq('id', championshipId)
        .map((list) {
          if (list.isEmpty) return null;
          try {
            return Championship.fromFirestore(list.first, championshipId);
          } catch (e) {
            debugPrint('Error parsing realtime championship stream: $e');
            return null;
          }
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) async {
            final refreshed = await getChampionshipById(championshipId);
            sink.add(refreshed);
          },
        )
        .handleError((error) {
          debugPrint('Handled realtime error in getSingleChampionshipStream: $error');
        });
  }

  /// حذف البطولة بكامل بياناتها ومبارياتها وتشكيلاتها بأمان
  Future<bool> deleteChampionship(String championshipId) async {
    try {
      // 1. حذف تشكيلات البطولة
      try {
        final rosters = await _supabase
            .from('championship_rosters')
            .select('id')
            .eq('championship_id', championshipId);
        final rosterIds = (rosters as List).map((r) => r['id'].toString()).toList();
        if (rosterIds.isNotEmpty) {
          try {
            await _supabase
                .from('championship_roster_players')
                .delete()
                .inFilter('roster_id', rosterIds);
          } catch (_) {}
          try {
            await _supabase
                .from('championship_roster_guests')
                .delete()
                .inFilter('roster_id', rosterIds);
          } catch (_) {}
        }
        await _supabase
            .from('championship_rosters')
            .delete()
            .eq('championship_id', championshipId);
      } catch (rosterErr) {
        debugPrint('Championship rosters cleanup notice: $rosterErr');
      }

      // 2. حذف مباريات البطولة
      try {
        await _supabase
            .from('tournament_matches')
            .delete()
            .eq('championship_id', championshipId);
      } catch (matchErr) {
        debugPrint('Tournament matches cleanup notice: $matchErr');
      }

      // 3. حذف سجل البطولة الأساسي
      await _supabase
          .from('championships')
          .delete()
          .eq('id', championshipId);

      debugPrint('Championship $championshipId deleted successfully.');
      return true;
    } catch (e) {
      debugPrint('Error deleting championship: $e');
      return false;
    }
  }

  /// فحص تكرار تسجيل اللاعبين أو الضيوف في فرق أخرى داخل نفس البطولة
  Future<List<String>> checkDuplicatePlayersInChampionship({
    required String championshipId,
    required String currentTeamId,
    required List<String> playerIds,
    required List<String> guestNames,
  }) async {
    final List<String> duplicateNames = [];
    try {
      final rosters = await _supabase
          .from('championship_rosters')
          .select('id, team_id, guest_names, player_ids')
          .eq('championship_id', championshipId)
          .neq('team_id', currentTeamId);

      final otherRosters = List<Map<String, dynamic>>.from(rosters as List);
      final Set<String> registeredPlayerIds = {};
      final Set<String> registeredGuestNames = {};
      final List<String> otherRosterIds = [];

      for (var r in otherRosters) {
        final rosterId = r['id'].toString();
        otherRosterIds.add(rosterId);
        final pIds = r['player_ids'] as List? ?? [];
        for (var p in pIds) {
          if (p != null && p.toString().isNotEmpty) registeredPlayerIds.add(p.toString());
        }
        final gNames = r['guest_names'] as List? ?? [];
        for (var g in gNames) {
          if (g != null && g.toString().trim().isNotEmpty) {
            registeredGuestNames.add(g.toString().trim().toLowerCase());
          }
        }
      }

      // Batch fetch all players across other rosters in 1 query instead of N+1
      if (otherRosterIds.isNotEmpty) {
        try {
          final rp = await _supabase
              .from('championship_roster_players')
              .select('player_id')
              .inFilter('roster_id', otherRosterIds);
          for (var item in (rp as List)) {
            final pId = item['player_id']?.toString();
            if (pId != null && pId.isNotEmpty) registeredPlayerIds.add(pId);
          }
        } catch (_) {}
      }

      // Batch fetch duplicate user names in 1 query instead of loop queries
      final matchingDupIds = playerIds.where((p) => registeredPlayerIds.contains(p)).toList();
      if (matchingDupIds.isNotEmpty) {
        try {
          final userDocs = await _supabase
              .from('users')
              .select('name')
              .inFilter('id', matchingDupIds);
          for (var u in (userDocs as List)) {
            final name = u['name']?.toString() ?? 'لاعب مسجل';
            duplicateNames.add(name);
          }
        } catch (_) {
          duplicateNames.add('لاعب مسجل مسبقاً');
        }
      }

      for (final g in guestNames) {
        if (registeredGuestNames.contains(g.trim().toLowerCase())) {
          duplicateNames.add(g.trim());
        }
      }
    } catch (e) {
      debugPrint('Error checking duplicate players in championship: $e');
    }
    return duplicateNames;
  }

  /// فحص تعارض مواعيد المباريات لنفس الفرق
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
          .select('id, scheduled_time, home_team_id, away_team_id, home_team_name, away_team_name')
          .eq('championship_id', championshipId)
          .neq('id', matchId)
          .not('scheduled_time', 'is', null);

      final newMatchStart = scheduledTime;
      final newMatchEnd = scheduledTime.add(Duration(minutes: matchDurationMinutes));

      for (var m in (matchesRes as List)) {
        final rawTime = m['scheduled_time']?.toString();
        if (rawTime == null) continue;
        final existingStart = DateTime.parse(rawTime).toLocal();
        final existingEnd = existingStart.add(Duration(minutes: matchDurationMinutes));

        final bool overlaps = newMatchStart.isBefore(existingEnd) && newMatchEnd.isAfter(existingStart);
        if (overlaps) {
          final mHomeId = m['home_team_id']?.toString();
          final mAwayId = m['away_team_id']?.toString();

          if (homeTeamId != null && (homeTeamId == mHomeId || homeTeamId == mAwayId)) {
            final tName = m['home_team_name'] ?? 'الفريق';
            return 'تعارض: فريق ($tName) لديه مباراة أخرى مجدولة في نفس التوقيت (${AppDateFormatter.formatTime(existingStart, 'ar')})!';
          }
          if (awayTeamId != null && (awayTeamId == mHomeId || awayTeamId == mAwayId)) {
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

  /// Atomically marks a championship prize as delivered in the financial ledger
  Future<Map<String, dynamic>> markChampionshipPrizeDelivered(
    String championshipId, {
    String? notes,
  }) async {
    try {
      final res = await _supabase.rpc(
        'mark_championship_prize_delivered_atomic',
        params: {
          'p_championship_id': championshipId,
          'p_notes': notes,
        },
      );
      return Map<String, dynamic>.from(res as Map);
    } catch (e, s) {
      VSPLogger.e('Error marking championship prize delivered', e, s);
      rethrow;
    }
  }

  /// Insert championship roster
  Future<void> insertChampionshipRoster({
    required String championshipId,
    required String teamId,
    required List<String> guestNames,
    List<String> playerIds = const [],
  }) async {
    await _supabase.from('championship_rosters').insert({
      'championship_id': championshipId,
      'team_id': teamId,
      'player_ids': playerIds,
      'guest_names': guestNames,
    });
  }

  /// Stream single championship updates
  Stream<List<Map<String, dynamic>>> streamChampionshipRaw(String championshipId) {
    return _supabase
        .from('championships')
        .stream(primaryKey: ['id'])
        .eq('id', championshipId)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) => sink.add([]),
        )
        .handleError((e) {
          VSPLogger.w('Handled realtime error in championship stream: $e');
        });
  }

  /// Check if 1v1 tournament order was paid
  Future<bool> is1v1OrderPaid(String orderReference) async {
    try {
      final res = await _supabase
          .from('vsp_1v1_tournament_orders')
          .select('payment_status')
          .eq('order_reference', orderReference)
          .maybeSingle();
      return res != null && res['payment_status'] == 'paid';
    } catch (e) {
      debugPrint('Error checking 1v1 order paid status: $e');
      return false;
    }
  }
}

