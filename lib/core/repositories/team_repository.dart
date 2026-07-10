import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../repositories/notification_repository.dart';
import '../utils/phone_utils.dart';

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

  Future<void> updateMatchResult(String bookingId, String homeTeamId, String awayTeamId, MatchOutcome finalOutcome) async {
    try {
      await _supabase.from('bookings').update({
        'status': BookingStatus.completed.name,
        'final_outcome': finalOutcome.name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', bookingId);
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
      final pgData = {
        'name': data['name'],
        'captain_id': (data['memberUids'] as List?)?.first?.toString(),
        'captain_name': data['captainName'] ?? 'Captain',
        'captain_phone': PhoneUtils.normalize(data['captainPhone'] ?? ''),
        'logo_url': data['logoUrl'] ?? '',
        'date': data['date'] ?? 'Upcoming',
        'stadium': data['stadium'] ?? 'TBD',
        'price_per_person': data['pricePerPerson'] ?? 50.0,
        'points': 0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
        'matches_played': 0,
        'current_winning_streak': 0,
        'unlocked_badges': ['explorer'],
        'played_opponents': [],
        'championships_won': 0,
        'governorate': data['governorate'] ?? 'Cairo',
        'sport_type': data['sportType'] ?? 'Football',
      };

      final response = await _supabase
          .from('teams')
          .insert(pgData)
          .select('id')
          .single();
      
      final teamId = response['id'].toString();

      final List memberUids = List.from(data['memberUids'] ?? []);
      for (final uid in memberUids) {
        await _supabase.from('team_members').insert({
          'team_id': teamId,
          'user_id': uid.toString(),
        });
      }

      // ── Anti-Silent Kidnapping Notification ──
      if (memberUids.length > 1) {
        for (int i = 1; i < memberUids.length; i++) {
          _sendJoinNotification(memberUids[i].toString());
        }
      }

      return teamId;
    } catch (e) {
      debugPrint('Error creating team: $e');
      return null;
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

  Stream<List<Team>> getTeams({String? governorate}) {
    return _supabase
        .from('teams')
        .stream(primaryKey: ['id'])
        .map((list) {
          return list.map((data) {
            if (governorate != null && data['governorate'] != governorate) {
              return null;
            }
            return Team.fromFirestore(data, data['id'].toString());
          }).whereType<Team>().toList();
        });
  }

  Future<List<Team>> searchOpponentTeams(String query) async {
    try {
      final response = await _supabase
          .from('teams')
          .select()
          .ilike('name', '%$query%');
      
      final List<Team> teams = [];
      for (final doc in (response as List)) {
        final teamId = doc['id'].toString();
        final memberUids = await getTeamMemberUids(teamId);
        final playerImages = await getTeamPlayerImages(memberUids);
        
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
          .select()
          .inFilter('id', team.playedOpponents);
          
      final List<Team> teams = [];
      for (final doc in (response as List)) {
        final id = doc['id'].toString();
        final memberUids = await getTeamMemberUids(id);
        final playerImages = await getTeamPlayerImages(memberUids);
        
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
    return {'team1Wins': 0, 'draws': 0, 'team2Wins': 0};
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
      await _supabase.from('team_members').insert({
        'team_id': teamId,
        'user_id': userId,
      });
      _sendJoinNotification(userId);
    } on PostgrestException catch (e) {
      if (e.message.contains('الحد الأقصى') || e.message.contains('limit')) {
        throw Exception("تنبيه: اللاعب وصل للحد الأقصى للانضمام للفرق (3 فرق كحد أقصى).");
      }
      rethrow;
    } catch (e) {
      debugPrint('Error adding member to team: $e');
      rethrow;
    }
  }

  Future<void> removeMemberFromTeam(String teamId, String userId, String imageUrl) async {
    try {
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

      // Also check ongoing or open championships
      final championshipsResponse = await _supabase
          .from('championships')
          .select('joined_teams')
          .inFilter('status', ['open', 'ongoing']);

      bool hasActiveTournament = false;
      for (var row in championshipsResponse as List) {
        final List joined = List.from(row['joined_teams'] ?? []);
        if (joined.contains(teamId)) {
          hasActiveTournament = true;
          break;
        }
      }
    
      if (hasActiveMatch || hasActiveTournament) {
        throw Exception("active_match_or_tournament_error");
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
      final pgData = <String, dynamic>{};
      if (data.containsKey('name')) pgData['name'] = data['name'];
      if (data.containsKey('captainName')) pgData['captain_name'] = data['captainName'];
      if (data.containsKey('captainImageUrl')) pgData['captain_image_url'] = data['captainImageUrl'];
      if (data.containsKey('logoUrl')) pgData['logo_url'] = data['logoUrl'];
      if (data.containsKey('date')) pgData['date'] = data['date'];
      if (data.containsKey('stadium')) pgData['stadium'] = data['stadium'];
      if (data.containsKey('pricePerPerson')) pgData['price_per_person'] = data['pricePerPerson'];
      if (data.containsKey('points')) pgData['points'] = data['points'];
      if (data.containsKey('wins')) pgData['wins'] = data['wins'];
      if (data.containsKey('draws')) pgData['draws'] = data['draws'];
      if (data.containsKey('losses')) pgData['losses'] = data['losses'];
      if (data.containsKey('matchesPlayed')) pgData['matches_played'] = data['matchesPlayed'];
      if (data.containsKey('currentWinningStreak')) pgData['current_winning_streak'] = data['currentWinningStreak'];
      if (data.containsKey('unlockedBadges')) pgData['unlocked_badges'] = data['unlockedBadges'];
      if (data.containsKey('playedOpponents')) pgData['played_opponents'] = data['playedOpponents'];
      if (data.containsKey('beatenOpponents')) pgData['beaten_opponents'] = data['beatenOpponents'];
      if (data.containsKey('championshipsWon')) pgData['championships_won'] = data['championshipsWon'];
      if (data.containsKey('governorate')) pgData['governorate'] = data['governorate'];
      if (data.containsKey('sportType')) pgData['sport_type'] = data['sportType'];

      if (pgData.isEmpty) return true;

      await _supabase.from('teams').update(pgData).eq('id', teamId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTeam(String teamId) async {
    try {
      final champs = await _supabase.from('championships').select('id').contains('joined_teams', [teamId]).inFilter('status', ['open', 'ongoing']);
      if ((champs as List).isNotEmpty) throw Exception('team_in_tournament');
      await _supabase.from('team_members').delete().eq('team_id', teamId);
      await _supabase.from('teams').delete().eq('id', teamId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _sendJoinNotification(String userId) async {
    try {
      await NotificationRepository().sendNotification(
        userId,
        AppNotification(
          id: '',
          title: "⚽ New Team Transfer!",
          body: "You have been drafted to join a new team. Get ready for the next match!",
          type: "info",
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('Error sending join notification: $e');
    }
  }
}

