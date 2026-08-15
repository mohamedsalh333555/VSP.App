import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../repositories/notification_repository.dart';
import '../repositories/team_repository.dart';
import '../utils/app_date_formatter.dart';
import '../constants/egypt_governorates.dart';
import '../services/notification_handler.dart';
import '../../data/models.dart';

class TournamentRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ==================== CHAMPIONSHIPS ====================
  
  // Get all championships
  // 🛡️ SECURITY: For players (isOwner=false), only show championships where is_approved=true.
  // Championships become approved automatically when the owner's stadium gets verified by admin.
  // Owners can always see their own championships regardless of approval status.
  Stream<List<Championship>> getChampionshipsStream({
    String? governorate, 
    String? sportType,
    bool isOwner = false,
    String? ownerId,
  }) async* {
    // 1. ⚡ Emit immediate results via REST API query so UI never stays empty or waits for WebSocket connection
    try {
      final List<dynamic> response = await _supabase.from('championships').select();
      final items = _parseChampionshipsList(
        response,
        governorate: governorate,
        sportType: sportType,
        isOwner: isOwner,
        ownerId: ownerId,
      );
      yield items;
    } catch (e) {
      debugPrint('Error fetching initial championships via REST: $e');
    }

    // 2. 📡 Listen to Real-time Stream for updates
    yield* _supabase
        .from('championships')
        .stream(primaryKey: ['id'])
        .map((list) {
          return _parseChampionshipsList(
            list,
            governorate: governorate,
            sportType: sportType,
            isOwner: isOwner,
            ownerId: ownerId,
          );
        });
  }

  Future<Championship?> getChampionshipById(String id) async {
    try {
      final data = await _supabase.from('championships').select().eq('id', id).maybeSingle();
      if (data == null) return null;
      return Championship.fromFirestore(data, data['id'].toString());
    } catch (e) {
      debugPrint('Error fetching championship by id: $e');
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
      final sanitizedData = Map<String, dynamic>.from(data);
      sanitizedData.remove('joinedTeams');
      sanitizedData.remove('joined_teams');
      sanitizedData.remove('status');
      sanitizedData.remove('creatorId');
      sanitizedData.remove('creator_id');

      String rawType = (sanitizedData['type'] ?? 'Cup').toString();
      String dbType = rawType;
      if (rawType == 'GroupsAndKnockout' || rawType == 'groups_and_knockout') {
        dbType = 'Groups';
      }

      final pgData = {
        'name': sanitizedData['name'],
        'type': dbType,
        'sport_type': sanitizedData['sportType'] ?? sanitizedData['sport_type'] ?? 'Football',
        'logo_url': sanitizedData['logoUrl'] ?? sanitizedData['logo_url'] ?? '',
        'start_date': sanitizedData['startDate'] ?? sanitizedData['start_date'],
        'end_date': sanitizedData['endDate'] ?? sanitizedData['end_date'],
        'entry_fee': sanitizedData['entryFee'] ?? sanitizedData['entry_fee'] ?? 0.0,
        'grand_prize': sanitizedData['grandPrize'] ?? sanitizedData['grand_prize'] ?? 0.0,
        'max_teams': sanitizedData['maxTeams'] ?? sanitizedData['max_teams'] ?? 16,
        'owner_id': (sanitizedData['ownerId'] != null && sanitizedData['ownerId'].toString().isNotEmpty)
            ? sanitizedData['ownerId']
            : (sanitizedData['owner_id'] != null && sanitizedData['owner_id'].toString().isNotEmpty
                ? sanitizedData['owner_id']
                : (_supabase.auth.currentUser?.id ?? '')),
        'governorate': sanitizedData['governorate'] ?? 'Cairo',
        'rules': sanitizedData['rules'] ?? '',
        'status': 'open',
        'is_approved': true, // Directly open and approved for owner
        'joined_teams': [],
        'paid_teams': [],
        'payment_methods': sanitizedData['paymentMethods'] ?? ['cash'],
        
        // Flat settings columns
        'max_players_per_team': sanitizedData['maxPlayersPerTeam'] ?? sanitizedData['max_players_per_team'] ?? 11,
        'min_players_per_team': sanitizedData['minPlayersPerTeam'] ?? sanitizedData['min_players_per_team'] ?? 5,
        'winning_points': sanitizedData['winningPoints'] ?? sanitizedData['winning_points'] ?? 3,
        'draw_points': sanitizedData['drawPoints'] ?? sanitizedData['draw_points'] ?? 1,
        'loss_points': sanitizedData['lossPoints'] ?? sanitizedData['loss_points'] ?? 0,
        'match_duration': sanitizedData['matchDuration'] ?? sanitizedData['match_duration'] ?? 30,
        'is_back_and_forth': sanitizedData['isBackAndForth'] ?? sanitizedData['is_back_and_forth'] ?? false,
        'trophy_medals': sanitizedData['trophyMedals'] ?? sanitizedData['trophy_medals'] ?? true,
        'red_card_suspension': sanitizedData['redCardSuspension'] ?? sanitizedData['red_card_suspension'] ?? true,
        'fair_play_scoring': sanitizedData['fairPlayScoring'] ?? sanitizedData['fair_play_scoring'] ?? false,
      };

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
    } catch (e) {
      debugPrint('Error creating championship: $e');
      rethrow;
    }
  }

  /// 🏆 تفعيل ونشر البطولة للمالك (مجانية 100% بدون أي رسوم إنشاء)
  Future<bool> activateChampionship(String championshipId) async {
    try {
      await _supabase.from('championships').update({
        'status': 'open',
        'is_approved': true,
        'creation_fee_paid': true,
      }).eq('id', championshipId);
      debugPrint('✅ Championship $championshipId activated successfully (100% Free).');
      return true;
    } catch (e) {
      debugPrint('❌ Error activating championship: $e');
      return false;
    }
  }

  Future<bool> updateChampionship(String id, Map<String, dynamic> data) async {
    try {
      final pgData = <String, dynamic>{};
      if (data.containsKey('name')) pgData['name'] = data['name'];
      if (data.containsKey('type')) pgData['type'] = data['type'];
      if (data.containsKey('sportType')) pgData['sport_type'] = data['sportType'];
      if (data.containsKey('sport_type')) pgData['sport_type'] = data['sport_type'];
      if (data.containsKey('logoUrl')) pgData['logo_url'] = data['logoUrl'];
      if (data.containsKey('logo_url')) pgData['logo_url'] = data['logo_url'];
      if (data.containsKey('startDate')) pgData['start_date'] = data['startDate'];
      if (data.containsKey('start_date')) pgData['start_date'] = data['start_date'];
      if (data.containsKey('endDate')) pgData['end_date'] = data['endDate'];
      if (data.containsKey('end_date')) pgData['end_date'] = data['end_date'];
      if (data.containsKey('entryFee')) pgData['entry_fee'] = data['entryFee'];
      if (data.containsKey('entry_fee')) pgData['entry_fee'] = data['entry_fee'];
      if (data.containsKey('grandPrize')) pgData['grand_prize'] = data['grandPrize'];
      if (data.containsKey('grand_prize')) pgData['grand_prize'] = data['grand_prize'];
      if (data.containsKey('maxTeams')) pgData['max_teams'] = data['maxTeams'];
      if (data.containsKey('max_teams')) pgData['max_teams'] = data['max_teams'];
      if (data.containsKey('governorate')) pgData['governorate'] = data['governorate'];
      if (data.containsKey('rules')) pgData['rules'] = data['rules'];
      if (data.containsKey('paymentMethods')) pgData['payment_methods'] = data['paymentMethods'];
      if (data.containsKey('payment_methods')) pgData['payment_methods'] = data['payment_methods'];

      // Flat settings columns
      if (data.containsKey('maxPlayersPerTeam')) pgData['max_players_per_team'] = data['maxPlayersPerTeam'];
      if (data.containsKey('max_players_per_team')) pgData['max_players_per_team'] = data['max_players_per_team'];
      if (data.containsKey('minPlayersPerTeam')) pgData['min_players_per_team'] = data['minPlayersPerTeam'];
      if (data.containsKey('min_players_per_team')) pgData['min_players_per_team'] = data['min_players_per_team'];
      if (data.containsKey('winningPoints')) pgData['winning_points'] = data['winningPoints'];
      if (data.containsKey('winning_points')) pgData['winning_points'] = data['winning_points'];
      if (data.containsKey('drawPoints')) pgData['draw_points'] = data['drawPoints'];
      if (data.containsKey('draw_points')) pgData['draw_points'] = data['draw_points'];
      if (data.containsKey('lossPoints')) pgData['loss_points'] = data['lossPoints'];
      if (data.containsKey('loss_points')) pgData['loss_points'] = data['loss_points'];
      if (data.containsKey('matchDuration')) pgData['match_duration'] = data['matchDuration'];
      if (data.containsKey('match_duration')) pgData['match_duration'] = data['match_duration'];
      if (data.containsKey('isBackAndForth')) pgData['is_back_and_forth'] = data['isBackAndForth'];
      if (data.containsKey('is_back_and_forth')) pgData['is_back_and_forth'] = data['is_back_and_forth'];
      if (data.containsKey('trophyMedals')) pgData['trophy_medals'] = data['trophyMedals'];
      if (data.containsKey('trophy_medals')) pgData['trophy_medals'] = data['trophy_medals'];
      if (data.containsKey('redCardSuspension')) pgData['red_card_suspension'] = data['redCardSuspension'];
      if (data.containsKey('red_card_suspension')) pgData['red_card_suspension'] = data['red_card_suspension'];
      if (data.containsKey('fairPlayScoring')) pgData['fair_play_scoring'] = data['fairPlayScoring'];
      if (data.containsKey('fair_play_scoring')) pgData['fair_play_scoring'] = data['fair_play_scoring'];

      if (data.containsKey('settings') && data['settings'] is Map) {
        final settings = data['settings'] as Map;
        if (settings.containsKey('maxPlayers')) pgData['max_players_per_team'] = settings['maxPlayers'];
        if (settings.containsKey('max_players')) pgData['max_players_per_team'] = settings['max_players'];
        if (settings.containsKey('minPlayers')) pgData['min_players_per_team'] = settings['minPlayers'];
        if (settings.containsKey('min_players')) pgData['min_players_per_team'] = settings['min_players'];
        if (settings.containsKey('winningPoints')) pgData['winning_points'] = settings['winningPoints'];
        if (settings.containsKey('winning_points')) pgData['winning_points'] = settings['winning_points'];
        if (settings.containsKey('drawPoints')) pgData['draw_points'] = settings['drawPoints'];
        if (settings.containsKey('draw_points')) pgData['draw_points'] = settings['draw_points'];
        if (settings.containsKey('lossPoints')) pgData['loss_points'] = settings['lossPoints'];
        if (settings.containsKey('loss_points')) pgData['loss_points'] = settings['loss_points'];
        if (settings.containsKey('matchDuration')) pgData['match_duration'] = settings['matchDuration'];
        if (settings.containsKey('match_duration')) pgData['match_duration'] = settings['match_duration'];
        if (settings.containsKey('isBackAndForth')) pgData['is_back_and_forth'] = settings['isBackAndForth'];
        if (settings.containsKey('is_back_and_forth')) pgData['is_back_and_forth'] = settings['is_back_and_forth'];
        if (settings.containsKey('trophyMedals')) pgData['trophy_medals'] = settings['trophyMedals'];
        if (settings.containsKey('trophy_medals')) pgData['trophy_medals'] = settings['trophy_medals'];
        if (settings.containsKey('redCardSuspension')) pgData['red_card_suspension'] = settings['redCardSuspension'];
        if (settings.containsKey('red_card_suspension')) pgData['red_card_suspension'] = settings['red_card_suspension'];
        if (settings.containsKey('fairPlayScoring')) pgData['fair_play_scoring'] = settings['fairPlayScoring'];
        if (settings.containsKey('fair_play_scoring')) pgData['fair_play_scoring'] = settings['fair_play_scoring'];
      }

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

      if (champ.joinedTeams.length >= champ.maxTeams) {
        throw Exception('عذراً، البطولة اكتمل عددها بالفعل.');
      }

      if (champ.joinedTeams.contains(teamId)) {
        throw Exception('لقد انضمت مجموعتك لهذه البطولة بالفعل.');
      }

      final updatedJoined = List<String>.from(champ.joinedTeams)..add(teamId);
      final updatedPaid = List<String>.from(champ.paidTeams);
      if (isPaid && !updatedPaid.contains(teamId)) {
        updatedPaid.add(teamId);
      }

      await _supabase
          .from('championships')
          .update({
            'joined_teams': updatedJoined,
            'paid_teams': updatedPaid,
          })
          .eq('id', championshipId);

      // 💳 تسجيل معاملة اشتراك البطولة في جدول المعاملات المالية
      if (isPaid && champ.entryFee > 0) {
        try {
          await _supabase.from('transactions').insert({
            'championship_id': championshipId,
            'user_id': _supabase.auth.currentUser?.id,
            'amount': champ.entryFee,
            'type': 'digital',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (txErr) {
          debugPrint('⚠️ Non-blocking transaction logging notice: $txErr');
        }
      }

      // حفظ تشكيلة الفريق والأسماء الخارجية في الجدول
      try {
        await updateSingleTeamRoster(
          championshipId: championshipId,
          teamId: teamId,
          playerIds: selectedPlayerIds,
          guestNames: offlineGuestNames,
        );
      } catch (rosterErr) {
        debugPrint('⚠️ Non-blocking roster record notice: $rosterErr');
      }

      // 🔔 Notify tournament owner
      final ownerId = champ.ownerId;
      if (ownerId.isNotEmpty) {
        try {
          await NotificationHandler.notifyTeamJoinedTournament(
            ownerId: ownerId,
            teamName: team.name,
            tournamentName: champ.name,
            championshipId: championshipId,
          );
        } catch (e) {
          debugPrint('Error sending tournament joined notification: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error joining championship: $e');
      rethrow;
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
            title: "🏆 CHAMPIONS!",
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
      final response = await _supabase
          .from('teams')
          .select()
          .inFilter('id', ids);
      
      final List<Team> teams = [];
      for (final doc in (response as List)) {
        final teamId = doc['id'].toString();
        final memberUids = await TeamRepository().getTeamMemberUids(teamId);
        final playerImages = await TeamRepository().getTeamPlayerImages(memberUids);
        
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
      final champDoc = await _supabase
          .from('championships')
          .select()
          .eq('id', championshipId)
          .maybeSingle();
      if (champDoc == null) throw Exception('البطولة لا توجد.');

      final List<String> teamIds = List<String>.from(champDoc['joined_teams'] ?? champDoc['joinedTeams'] ?? []);
      int totalTeams = teamIds.length;
      if (totalTeams < 2) throw Exception('يجب وجود فريقين على الأقل لبدء البطولة.');

      final String? rawStartDate = champDoc['start_date'] ?? champDoc['startDate'];
      if (rawStartDate != null) {
        final startDate = DateTime.parse(rawStartDate);
        if (DateTime.now().isBefore(startDate)) {
          final formattedDate = AppDateFormatter.formatFullDate(startDate, 'ar');
          throw Exception('لا يمكن بدء البطولة أو إطلاق القرعة قبل الموعد المعلن للفرق ($formattedDate) لالتزام اللاعبين واستعدادهم.');
        }
      }

      final int configuredMaxTeams = champDoc['max_teams'] ?? champDoc['maxTeams'] ?? 16;
      
      // Calculate target bracket capacity (must be a power of 2: 4, 8, 16, 32)
      int bracketCapacity = 4;
      if (configuredMaxTeams == 4 || configuredMaxTeams == 8 || configuredMaxTeams == 16 || configuredMaxTeams == 32) {
        if (configuredMaxTeams >= totalTeams) {
          bracketCapacity = configuredMaxTeams;
        } else {
          int p = 4;
          while (p < totalTeams && p < 32) {
            p *= 2;
          }
          bracketCapacity = p;
        }
      } else {
        int p = 4;
        while (p < totalTeams && p < 32) {
          p *= 2;
        }
        bracketCapacity = p;
      }

      // Total rounds calculation for binary tree:
      // bracketCapacity = 32 -> 5 rounds (4,3,2,1,0)
      // bracketCapacity = 16 -> 4 rounds (3,2,1,0)
      // bracketCapacity = 8  -> 3 rounds (2,1,0)
      // bracketCapacity = 4  -> 2 rounds (1,0)
      int totalBracketRounds = (log(bracketCapacity) / log(2)).round();
      int startRoundIndex = totalBracketRounds - 1;

      final teams = await getTeamsByIds(teamIds);
      final teamMap = {for (var t in teams) t.id: t.name};

      final shuffledIds = List<String>.from(teamIds)..shuffle(Random());
      
      // Fill slots array of length bracketCapacity with team IDs (or null for BYEs)
      final List<String?> slots = List.generate(bracketCapacity, (index) {
        if (index < shuffledIds.length) {
          return shuffledIds[index];
        }
        return null; // BYE slot
      });

      final Map<String, String> matchUuidMap = {};
      String getMatchId(int r, int m) {
        final key = '${r}_$m';
        if (!matchUuidMap.containsKey(key)) {
          final rng = Random();
          final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
          bytes[6] = (bytes[6] & 0x0f) | 0x40;
          bytes[8] = (bytes[8] & 0x3f) | 0x80;
          final buf = StringBuffer();
          for (int i = 0; i < 16; i++) {
            if (i == 4 || i == 6 || i == 8 || i == 10) buf.write('-');
            buf.write(bytes[i].toRadixString(16).padLeft(2, '0'));
          }
          matchUuidMap[key] = buf.toString();
        }
        return matchUuidMap[key]!;
      }

      // Map to store match data for all rounds before bulk insertion
      final Map<String, Map<String, dynamic>> matchesMap = {};

      // 1. Initialize all matches for all rounds (from startRoundIndex down to 0)
      for (int r = startRoundIndex; r >= 0; r--) {
        int matchCount = (pow(2, r)).toInt();
        for (int m = 0; m < matchCount; m++) {
          final matchId = getMatchId(r, m);
          final nextMatchId = (r > 0) ? getMatchId(r - 1, m ~/ 2) : null;

          matchesMap[matchId] = {
            'id': matchId,
            'championship_id': championshipId,
            'round_index': r,
            'match_index': m,
            'next_match_id': nextMatchId,
            'home_team_id': null,
            'home_team_name': null,
            'away_team_id': null,
            'away_team_name': null,
            'home_score': null,
            'away_score': null,
            'winner_id': null,
          };
        }
      }

      // 2. Populate First Round (r = startRoundIndex)
      int firstRoundMatches = (pow(2, startRoundIndex)).toInt();
      for (int m = 0; m < firstRoundMatches; m++) {
        final matchId = getMatchId(startRoundIndex, m);
        final String? homeId = slots[m * 2];
        final String? awayId = slots[m * 2 + 1];

        final matchData = matchesMap[matchId]!;
        matchData['home_team_id'] = homeId;
        matchData['home_team_name'] = homeId != null ? teamMap[homeId] : null;
        matchData['away_team_id'] = awayId;
        matchData['away_team_name'] = awayId != null ? teamMap[awayId] : null;

        // 🛡️ BYE LOGIC handling
        if (homeId != null && awayId == null) {
          // Home team automatically advances via BYE
          matchData['winner_id'] = homeId;
          matchData['home_score'] = 0;
          matchData['away_score'] = 0;
          
          final nextMatchId = matchData['next_match_id'];
          if (nextMatchId != null && matchesMap.containsKey(nextMatchId)) {
            final nextMatch = matchesMap[nextMatchId]!;
            final isHomeSlot = m % 2 == 0;
            if (isHomeSlot) {
              nextMatch['home_team_id'] = homeId;
              nextMatch['home_team_name'] = teamMap[homeId];
            } else {
              nextMatch['away_team_id'] = homeId;
              nextMatch['away_team_name'] = teamMap[homeId];
            }
          }
        } else if (homeId == null && awayId != null) {
          // Away team automatically advances via BYE
          matchData['winner_id'] = awayId;
          matchData['home_score'] = 0;
          matchData['away_score'] = 0;

          final nextMatchId = matchData['next_match_id'];
          if (nextMatchId != null && matchesMap.containsKey(nextMatchId)) {
            final nextMatch = matchesMap[nextMatchId]!;
            final isHomeSlot = m % 2 == 0;
            if (isHomeSlot) {
              nextMatch['home_team_id'] = awayId;
              nextMatch['home_team_name'] = teamMap[awayId];
            } else {
              nextMatch['away_team_id'] = awayId;
              nextMatch['away_team_name'] = teamMap[awayId];
            }
          }
        }
      }

      // 3. Cascade any subsequent BYE auto-advances for rounds r = startRoundIndex - 1 down to 1
      bool isSubtreeEmpty(int roundIdx, int matchIdx) {
        final mId = getMatchId(roundIdx, matchIdx);
        final mData = matchesMap[mId];
        if (mData == null) return true;
        if (mData['home_team_id'] != null || mData['away_team_id'] != null || mData['winner_id'] != null) {
          return false;
        }
        if (roundIdx < startRoundIndex) {
          bool homeSub = isSubtreeEmpty(roundIdx + 1, matchIdx * 2);
          bool awaySub = isSubtreeEmpty(roundIdx + 1, matchIdx * 2 + 1);
          return homeSub && awaySub;
        }
        return true;
      }

      for (int r = startRoundIndex - 1; r >= 1; r--) {
        int matchCount = (pow(2, r)).toInt();
        for (int m = 0; m < matchCount; m++) {
          final matchId = getMatchId(r, m);
          final matchData = matchesMap[matchId]!;

          final String? homeId = matchData['home_team_id'];
          final String? awayId = matchData['away_team_id'];

          final bool feederAwayEmpty = isSubtreeEmpty(r + 1, m * 2 + 1);
          final bool feederHomeEmpty = isSubtreeEmpty(r + 1, m * 2);

          if (homeId != null && awayId == null && feederAwayEmpty) {
            matchData['winner_id'] = homeId;
            matchData['home_score'] = 0;
            matchData['away_score'] = 0;

            final nextMatchId = matchData['next_match_id'];
            if (nextMatchId != null && matchesMap.containsKey(nextMatchId)) {
              final nextMatch = matchesMap[nextMatchId]!;
              final isHomeSlot = m % 2 == 0;
              if (isHomeSlot) {
                nextMatch['home_team_id'] = homeId;
                nextMatch['home_team_name'] = teamMap[homeId];
              } else {
                nextMatch['away_team_id'] = homeId;
                nextMatch['away_team_name'] = teamMap[homeId];
              }
            }
          } else if (homeId == null && awayId != null && feederHomeEmpty) {
            matchData['winner_id'] = awayId;
            matchData['home_score'] = 0;
            matchData['away_score'] = 0;

            final nextMatchId = matchData['next_match_id'];
            if (nextMatchId != null && matchesMap.containsKey(nextMatchId)) {
              final nextMatch = matchesMap[nextMatchId]!;
              final isHomeSlot = m % 2 == 0;
              if (isHomeSlot) {
                nextMatch['home_team_id'] = awayId;
                nextMatch['home_team_name'] = teamMap[awayId];
              } else {
                nextMatch['away_team_id'] = awayId;
                nextMatch['away_team_name'] = teamMap[awayId];
              }
            }
          }
        }
      }

      // 4. Bulk insert matches into database
      final allMatchesToInsert = matchesMap.values.toList();
      if (allMatchesToInsert.isNotEmpty) {
        await _supabase.from('tournament_matches').insert(allMatchesToInsert);
      }

      await _supabase
          .from('championships')
          .update({'status': 'ongoing'})
          .eq('id', championshipId);

      _sendDrawNotifications(championshipId);

      debugPrint('✅ Tournament Fixtures generated successfully with BYE logic for $championshipId ($totalTeams teams)');
    } catch (e) {
      debugPrint('Error generating fixtures: $e');
      rethrow;
    }
  }

  Future<void> updateTournamentMatchScore({
    required String matchId,
    required int homeScore,
    required int awayScore,
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

      try {
        await _supabase
            .from('tournament_matches')
            .update({
              'home_score': homeScore,
              'away_score': awayScore,
              'winner_id': winnerId,
              'goal_details': goalDetails.map((g) => g.toMap()).toList(),
            })
            .eq('id', matchId);
      } catch (err) {
        debugPrint('⚠️ goal_details update fallback (column may be missing in DB): $err');
        await _supabase
            .from('tournament_matches')
            .update({
              'home_score': homeScore,
              'away_score': awayScore,
              'winner_id': winnerId,
            })
            .eq('id', matchId);
      }

      if (nextMatchId != null) {
        String slotField = (matchIndex % 2 == 0) ? 'home' : 'away';

        await _supabase
            .from('tournament_matches')
            .update({
              '${slotField}_team_id': winnerId,
              '${slotField}_team_name': winnerName,
            })
            .eq('id', nextMatchId);
      } else {
        // ── Final Match: Crown the Champion ──
        if (winnerId != null) {
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

  Stream<List<TournamentMatch>> getTournamentMatches(String championshipId) {
    return _supabase
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
        });
  }

  Future<bool> leaveChampionship(String championshipId, String teamId) async {
    try {
      final champResponse = await _supabase
          .from('championships')
          .select('joined_teams, paid_teams')
          .eq('id', championshipId)
          .maybeSingle();
      if (champResponse == null) throw Exception('البطولة لا توجد.');

      final List<String> joinedTeams = List<String>.from(champResponse['joined_teams'] ?? champResponse['joinedTeams'] ?? []);
      final List<String> paidTeams = List<String>.from(champResponse['paid_teams'] ?? champResponse['paidTeams'] ?? []);

      joinedTeams.remove(teamId);
      paidTeams.remove(teamId);

      await _supabase
          .from('championships')
          .update({
            'joined_teams': joinedTeams,
            'paid_teams': paidTeams,
          })
          .eq('id', championshipId);

      return true;
    } catch (e) {
      debugPrint('Error leaving championship: $e');
      return false;
    }
  }

  Future<void> _sendDrawNotifications(String championshipId) async {
    try {
      // 1. Get the championship name
      final champ = await _supabase
          .from('championships')
          .select('name')
          .eq('id', championshipId)
          .maybeSingle();
      if (champ == null) return;
      final champName = champ['name']?.toString() ?? 'البطولة';

      // 2. Fetch all matches of this championship
      final response = await _supabase
          .from('tournament_matches')
          .select()
          .eq('championship_id', championshipId);
      
      final List<Map<String, dynamic>> notificationsToInsert = [];
      final matchesList = response as List;

      for (final matchData in matchesList) {
        final String? homeId = matchData['home_team_id'];
        final String? awayId = matchData['away_team_id'];
        final String? homeName = matchData['home_team_name'];
        final String? awayName = matchData['away_team_name'];

        if (homeId != null && homeId.isNotEmpty && awayId != null && awayId.isNotEmpty) {
          final homeTeam = await TeamRepository().getTeam(homeId);
          if (homeTeam != null) {
            for (final uid in homeTeam.memberUids) {
              notificationsToInsert.add({
                'user_id': uid,
                'title': "🏆 تم إجراء قرعة البطولة!",
                'body': "فريقك سيواجه فريق ($awayName) في بطولة ($champName). تفقد جدول المباريات لمعرفة الموعد والتفاصيل!",
                'type': "info",
                'created_at': DateTime.now().toIso8601String(),
                'is_read': false,
              });
            }
          }

          final awayTeam = await TeamRepository().getTeam(awayId);
          if (awayTeam != null) {
            for (final uid in awayTeam.memberUids) {
              notificationsToInsert.add({
                'user_id': uid,
                'title': "🏆 تم إجراء قرعة البطولة!",
                'body': "فريقك سيواجه فريق ($homeName) في بطولة ($champName). تفقد جدول المباريات لمعرفة الموعد والتفاصيل!",
                'type': "info",
                'created_at': DateTime.now().toIso8601String(),
                'is_read': false,
              });
            }
          }
        }
      }

      // 🚀 Bulk insert notifications in a single network query
      if (notificationsToInsert.isNotEmpty) {
        await _supabase.from('notifications').insert(notificationsToInsert);
      }
    } catch (e) {
      debugPrint('Error sending draw notifications: $e');
    }
  }

  /// Fetch player rosters for home and away teams in a championship
  Future<Map<String, List<String>>> fetchRosters(String championshipId, String homeTeamId, String awayTeamId) async {
    List<String> homePlayers = [];
    List<String> awayPlayers = [];

    try {
      final homeRoster = await _supabase
          .from('championship_rosters')
          .select()
          .eq('championship_id', championshipId)
          .eq('team_id', homeTeamId)
          .maybeSingle();
      if (homeRoster != null) {
        final raw = homeRoster['guest_names'] ?? homeRoster['player_names'] ?? [];
        if (raw is List) homePlayers = List<String>.from(raw);
      }
    } catch (e) {
      debugPrint('Error fetching home roster: $e');
    }

    try {
      final awayRoster = await _supabase
          .from('championship_rosters')
          .select()
          .eq('championship_id', championshipId)
          .eq('team_id', awayTeamId)
          .maybeSingle();
      if (awayRoster != null) {
        final raw = awayRoster['guest_names'] ?? awayRoster['player_names'] ?? [];
        if (raw is List) awayPlayers = List<String>.from(raw);
      }
    } catch (e) {
      debugPrint('Error fetching away roster: $e');
    }

    return {'home': homePlayers, 'away': awayPlayers};
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
        final playerIdsRaw = roster['player_ids'] ?? [];
        final guestNamesRaw = roster['guest_names'] ?? roster['player_names'] ?? [];

        return {
          'player_ids': playerIdsRaw is List ? List<String>.from(playerIdsRaw) : <String>[],
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

      final payload = {
        'championship_id': championshipId,
        'team_id': teamId,
        'player_ids': playerIds,
        'guest_names': guestNames,
      };

      if (existing != null) {
        await _supabase
            .from('championship_rosters')
            .update(payload)
            .eq('id', existing['id']);
      } else {
        await _supabase
            .from('championship_rosters')
            .insert(payload);
      }
      debugPrint('✅ Tournament roster updated successfully for team $teamId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating tournament roster: $e');
      return false;
    }
  }

  /// ⚡ Auto-schedule matches in a specific round across 1, 2, or 4 days
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

  /// 🧹 Clear/reset all scheduled times for matches in a specific round
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

  /// ⚽ Get top scorers for a championship aggregated from match goal details
  Future<List<Map<String, dynamic>>> getTopScorersForChampionship(String championshipId) async {
    try {
      final response = await _supabase
          .from('tournament_matches')
          .select('goal_details, home_team_name, away_team_name')
          .eq('championship_id', championshipId);

      final Map<String, Map<String, dynamic>> scorerStats = {};

      int totalOwnGoals = 0;

      for (final matchData in (response as List)) {
        final rawGoals = matchData['goal_details'] as List?;
        if (rawGoals == null || rawGoals.isEmpty) continue;

        final homeTeamName = matchData['home_team_name']?.toString().trim() ?? '';
        final awayTeamName = matchData['away_team_name']?.toString().trim() ?? '';

        for (final item in rawGoals) {
          if (item is Map) {
            final bool isOwnGoal = item['is_own_goal'] == true || item['isOwnGoal'] == true;
            final playerName = item['player_name']?.toString().trim() ?? item['playerName']?.toString().trim() ?? '';
            
            // 🔄 Aggregate Own Goals under a dedicated category without naming any player
            if (isOwnGoal || 
                playerName.contains('عكسي') || 
                playerName == 'لاعب مجهول' || 
                playerName.contains('مجهول')) {
              totalOwnGoals++;
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

      if (totalOwnGoals > 0) {
        list.add({
          'name': 'أهداف عكسية',
          'team': 'إجمالي الأهداف العكسية في البطولة',
          'goals': totalOwnGoals,
          'isOwnGoalCategory': true,
        });
      }

      return list;
    } catch (e) {
      debugPrint('Error getting top scorers: $e');
      return [];
    }
  }

  /// 🧤 Get clean sheet teams/goalkeepers for a championship directly from database match scores
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
      final champDoc = await _supabase.from('championships').select().eq('id', championshipId).maybeSingle();
      if (champDoc == null) throw Exception('البطولة غير موجودة');

      final List<String> teamIds = (champDoc['joined_teams'] as List? ?? champDoc['joinedTeams'] as List?)?.map((e) => e.toString()).toList() ?? [];
      if (teamIds.length < 2) throw Exception('يجب وجود فريقين على الأقل لإنشاء الدوري');

      final teams = await getTeamsByIds(teamIds);
      final teamMap = {for (var t in teams) t.id: t.name};

      final isTwoLegs = champDoc['is_two_legs'] == true || champDoc['isTwoLegs'] == true;

      final List<String?> teamList = List.from(teamIds);
      if (teamList.length % 2 != 0) {
        teamList.add(null);
      }

      final int numTeams = teamList.length;
      final int numWeeks = numTeams - 1;
      final int matchesPerWeek = numTeams ~/ 2;

      List<Map<String, dynamic>> matchesToInsert = [];

      for (int week = 0; week < numWeeks; week++) {
        for (int match = 0; match < matchesPerWeek; match++) {
          final homeIdx = (week + match) % (numTeams - 1);
          var awayIdx = (numTeams - 1 - match + week) % (numTeams - 1);

          if (match == 0) {
            awayIdx = numTeams - 1;
          }

          final homeId = teamList[homeIdx];
          final awayId = teamList[awayIdx];

          if (homeId != null && awayId != null) {
            final matchUuid = const Uuid().v4();
            matchesToInsert.add({
              'id': matchUuid,
              'championship_id': championshipId,
              'championshipId': championshipId,
              'round_index': 0,
              'roundIndex': 0,
              'match_index': matchesToInsert.length,
              'matchIndex': matchesToInsert.length,
              'week_number': week + 1,
              'weekNumber': week + 1,
              'stage': 'league',
              'home_team_id': homeId,
              'homeTeamId': homeId,
              'home_team_name': teamMap[homeId] ?? 'فريق $homeId',
              'homeTeamName': teamMap[homeId] ?? 'فريق $homeId',
              'away_team_id': awayId,
              'awayTeamId': awayId,
              'away_team_name': teamMap[awayId] ?? 'فريق $awayId',
              'awayTeamName': teamMap[awayId] ?? 'فريق $awayId',
            });
          }
        }
      }

      if (isTwoLegs) {
        final int firstLegWeeks = numWeeks;
        final int firstLegMatchesCount = matchesToInsert.length;

        for (int i = 0; i < firstLegMatchesCount; i++) {
          final m = matchesToInsert[i];
          final matchUuid = const Uuid().v4();
          matchesToInsert.add({
            'id': matchUuid,
            'championship_id': championshipId,
            'championshipId': championshipId,
            'round_index': 0,
            'roundIndex': 0,
            'match_index': matchesToInsert.length,
            'matchIndex': matchesToInsert.length,
            'week_number': (m['week_number'] as int) + firstLegWeeks,
            'weekNumber': (m['week_number'] as int) + firstLegWeeks,
            'stage': 'league',
            'home_team_id': m['away_team_id'],
            'homeTeamId': m['away_team_id'],
            'home_team_name': m['away_team_name'],
            'homeTeamName': m['away_team_name'],
            'away_team_id': m['home_team_id'],
            'awayTeamId': m['home_team_id'],
            'away_team_name': m['home_team_name'],
            'awayTeamName': m['home_team_name'],
          });
        }
      }

      if (matchesToInsert.isNotEmpty) {
        await _supabase.from('tournament_matches').insert(matchesToInsert);
      }

      await _supabase.from('championships').update({'status': 'ongoing'}).eq('id', championshipId);
      debugPrint('✅ League Fixtures generated successfully (${matchesToInsert.length} matches)');
    } catch (e) {
      debugPrint('Error generating league fixtures: $e');
      rethrow;
    }
  }

  // ─── 3. توليد مباريات المجموعات ثم التصفيات (Groups + Knockout) ───
  Future<void> generateGroupsFixtures(String championshipId) async {
    try {
      final champDoc = await _supabase.from('championships').select().eq('id', championshipId).maybeSingle();
      if (champDoc == null) throw Exception('البطولة غير موجودة');

      final List<String> teamIds = (champDoc['joined_teams'] as List? ?? champDoc['joinedTeams'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final int numGroups = int.tryParse((champDoc['number_of_groups'] ?? champDoc['numberOfGroups'] ?? 2).toString()) ?? 2;

      if (teamIds.length < numGroups * 2) {
        throw Exception('عدد الفرق غير كافٍ لتقسيمهم على $numGroups مجموعات');
      }

      final teams = await getTeamsByIds(teamIds);
      final teamMap = {for (var t in teams) t.id: t.name};

      final shuffled = List<String>.from(teamIds)..shuffle(Random());
      final List<String> groupNames = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

      List<Map<String, dynamic>> matchesToInsert = [];

      for (int g = 0; g < numGroups; g++) {
        final String groupName = groupNames[g];
        final List<String> groupTeamIds = [];

        for (int i = 0; i < shuffled.length; i++) {
          if (i % numGroups == g) {
            groupTeamIds.add(shuffled[i]);
          }
        }

        final List<String?> teamList = List.from(groupTeamIds);
        if (teamList.length % 2 != 0) teamList.add(null);

        final int numTeams = teamList.length;
        final int numWeeks = numTeams - 1;
        final int matchesPerWeek = numTeams ~/ 2;

        for (int week = 0; week < numWeeks; week++) {
          for (int match = 0; match < matchesPerWeek; match++) {
            final homeIdx = (week + match) % (numTeams - 1);
            var awayIdx = (numTeams - 1 - match + week) % (numTeams - 1);
            if (match == 0) awayIdx = numTeams - 1;

            final homeId = teamList[homeIdx];
            final awayId = teamList[awayIdx];

            if (homeId != null && awayId != null) {
              matchesToInsert.add({
                'id': const Uuid().v4(),
                'championship_id': championshipId,
                'championshipId': championshipId,
                'round_index': 99,
                'roundIndex': 99,
                'match_index': matchesToInsert.length,
                'matchIndex': matchesToInsert.length,
                'group_name': groupName,
                'groupName': groupName,
                'week_number': week + 1,
                'weekNumber': week + 1,
                'stage': 'group_stage',
                'home_team_id': homeId,
                'homeTeamId': homeId,
                'home_team_name': teamMap[homeId] ?? 'فريق $homeId',
                'homeTeamName': teamMap[homeId] ?? 'فريق $homeId',
                'away_team_id': awayId,
                'awayTeamId': awayId,
                'away_team_name': teamMap[awayId] ?? 'فريق $awayId',
                'awayTeamName': teamMap[awayId] ?? 'فريق $awayId',
              });
            }
          }
        }
      }

      if (matchesToInsert.isNotEmpty) {
        await _supabase.from('tournament_matches').insert(matchesToInsert);
      }

      await _supabase.from('championships').update({'status': 'ongoing'}).eq('id', championshipId);
      debugPrint('✅ Group Stage Fixtures generated successfully');
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

      List<Map<String, String>> qualifiedTeams = [];

      for (int g = 0; g < numGroups; g++) {
        final groupName = groupNames[g];
        final standings = await getChampionshipStandings(championshipId, groupName: groupName);

        for (int i = 0; i < min(qualifyingPerGroup, standings.length); i++) {
          final row = standings[i];
          qualifiedTeams.add({
            'id': row['team_id'].toString(),
            'name': row['team_name'].toString(),
            'group': groupName,
          });
        }
      }

      if (qualifiedTeams.isEmpty) throw Exception('لا يوجد فرق متأهلة');

      int totalKnockoutTeams = qualifiedTeams.length;
      int targetCapacity = 2;
      while (targetCapacity < totalKnockoutTeams) {
        targetCapacity *= 2;
      }

      int totalRounds = (log(targetCapacity) / log(2)).round();
      int startRoundIndex = totalRounds - 1;

      List<Map<String, dynamic>> knockoutMatches = [];

      for (int r = startRoundIndex; r >= 0; r--) {
        int matchCount = (pow(2, r)).toInt();
        for (int m = 0; m < matchCount; m++) {
          final matchId = const Uuid().v4();
          knockoutMatches.add({
            'id': matchId,
            'championship_id': championshipId,
            'championshipId': championshipId,
            'round_index': r,
            'roundIndex': r,
            'match_index': m,
            'matchIndex': m,
            'stage': 'knockout',
          });
        }
      }

      int firstRoundMatchesCount = (pow(2, startRoundIndex)).toInt();
      for (int m = 0; m < firstRoundMatchesCount; m++) {
        if (m * 2 < qualifiedTeams.length) {
          knockoutMatches[m]['home_team_id'] = qualifiedTeams[m * 2]['id'];
          knockoutMatches[m]['homeTeamId'] = qualifiedTeams[m * 2]['id'];
          knockoutMatches[m]['home_team_name'] = qualifiedTeams[m * 2]['name'];
          knockoutMatches[m]['homeTeamName'] = qualifiedTeams[m * 2]['name'];
        }
        if (m * 2 + 1 < qualifiedTeams.length) {
          knockoutMatches[m]['away_team_id'] = qualifiedTeams[m * 2 + 1]['id'];
          knockoutMatches[m]['awayTeamId'] = qualifiedTeams[m * 2 + 1]['id'];
          knockoutMatches[m]['away_team_name'] = qualifiedTeams[m * 2 + 1]['name'];
          knockoutMatches[m]['awayTeamName'] = qualifiedTeams[m * 2 + 1]['name'];
        }
      }

      if (knockoutMatches.isNotEmpty) {
        await _supabase.from('tournament_matches').insert(knockoutMatches);
      }

      debugPrint('🚀 Successfully advanced group winners to Knockout stage!');
    } catch (e) {
      debugPrint('Error advancing groups to knockout: $e');
      rethrow;
    }
  }
}

