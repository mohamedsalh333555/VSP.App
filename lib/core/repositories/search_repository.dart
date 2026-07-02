import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';

class SearchRepository {
  final SupabaseClient _supabase;

  SearchRepository({SupabaseClient? supabaseClient}) 
      : _supabase = supabaseClient ?? Supabase.instance.client;

  Future<Map<String, List<dynamic>>> globalUnifiedSearch(String query) async {
    final term = query.trim();
    if (term.isEmpty) return {'stadiums': [], 'teams': [], 'championships': []};

    try {
      final stadiumResponse = await _supabase.from('stadiums')
          .select()
          .ilike('name', '%$term%')
          .limit(5);
      final stadiums = (stadiumResponse as List)
          .map((d) => Stadium.fromFirestore(d, d['id'].toString()))
          .toList();

      final teamResponse = await _supabase.from('teams')
          .select()
          .ilike('name', '%$term%')
          .limit(5);
      final teams = (teamResponse as List)
          .map((d) => Team.fromFirestore(d, d['id'].toString()))
          .toList();

      final champResponse = await _supabase.from('championships')
          .select()
          .ilike('name', '%$term%')
          .limit(5);
      final championships = (champResponse as List)
          .map((d) => Championship.fromFirestore(d, d['id'].toString()))
          .toList();

      return {
        'stadiums': stadiums,
        'teams': teams,
        'championships': championships,
      };
    } catch (e) {
      return {'stadiums': [], 'teams': [], 'championships': []};
    }
  }
}
