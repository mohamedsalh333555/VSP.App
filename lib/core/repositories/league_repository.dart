import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';

class LeagueRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  LeagueRepository({dynamic firestore});

  Stream<List<VSP1v1Player>> get1v1Standings() {
    return _supabase
        .from('vsp_1vs1_players')
        .stream(primaryKey: ['id'])
        .map((list) {
          if (list.isEmpty) return [];
          
          final sortedList = List<Map<String, dynamic>>.from(list);
          sortedList.sort((a, b) {
            final pointsA = (a['total_points'] ?? 0) as int;
            final pointsB = (b['total_points'] ?? 0) as int;
            return pointsB.compareTo(pointsA);
          });

          List<VSP1v1Player> players = [];
          for (int i = 0; i < sortedList.length; i++) {
            var data = sortedList[i];
            
            final mappedData = {
              'name': data['name'] ?? 'Unknown',
              'avatarUrl': data['avatar_url'] ?? '',
              'totalPoints': data['total_points'] ?? 0,
              'skillPoints': data['skill_points'] ?? 0,
              'goals': data['goals'] ?? 0,
              'tackles': data['tackles'] ?? 0,
              'titles': data['titles'] ?? 0,
              'rank': i + 1, 
              'trend': data['trend'] ?? 'stable',
            };
            players.add(VSP1v1Player.fromFirestore(mappedData, data['id'].toString()));
          }
          return players;
        });
  }

  Future<int> get1v1RegistrationsCount() async {
    try {
      final response = await _supabase
          .from('vsp_1v1_registrations')
          .select('id')
          .inFilter('status', ['pending', 'approved']);
      return (response as List).length;
    } catch (e) {
      debugPrint('Error getting 1v1 registrations count: $e');
      return 0;
    }
  }

  Future<bool> hasUserRegistered1v1(String userId) async {
    try {
      final response = await _supabase
          .from('vsp_1v1_registrations')
          .select('id')
          .eq('user_id', userId)
          .inFilter('status', ['pending', 'approved'])
          .maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('Error checking user 1v1 registration: $e');
      return false;
    }
  }

  Future<bool> registerFor1v1(String userId) async {
    try {
      await _supabase.from('vsp_1v1_registrations').insert({
        'user_id': userId,
        'status': 'pending',
      });
      return true;
    } catch (e) {
      debugPrint('Error registering for 1v1: $e');
      return false;
    }
  }

  Stream<int> stream1v1RegistrationsCount() {
    return _supabase
        .from('vsp_1v1_registrations')
        .stream(primaryKey: ['id'])
        .map((list) {
          return list.where((item) {
            final status = item['status'];
            return status == 'pending' || status == 'approved';
          }).length;
        });
  }
}
