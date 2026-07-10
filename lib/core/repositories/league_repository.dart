import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';

class LeagueRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Support old constructor to avoid compile error in DatabaseService
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
}
