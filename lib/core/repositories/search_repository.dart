import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../services/logger_service.dart';

class SearchRepository {
  final SupabaseClient _supabase;

  SearchRepository({SupabaseClient? supabaseClient}) 
      : _supabase = supabaseClient ?? Supabase.instance.client;

  Future<Map<String, List<dynamic>>> globalUnifiedSearch(String query) async {
    final term = query.trim();
    if (term.isEmpty) return {'stadiums': [], 'teams': [], 'championships': []};

    try {
      final response = await _supabase.rpc('global_search', params: {'search_term': term});
      final Map<String, dynamic> data = response is String 
          ? Map<String, dynamic>.from(json.decode(response)) 
          : Map<String, dynamic>.from(response as Map);

      final stadiumsList = data['stadiums'] as List? ?? [];
      final teamsList = data['teams'] as List? ?? [];
      final championshipsList = data['championships'] as List? ?? [];

      final stadiums = stadiumsList
          .map((d) => Stadium.fromFirestore(d as Map<String, dynamic>, d['id'].toString()))
          .toList();

      final teams = teamsList
          .map((d) => Team.fromFirestore(d as Map<String, dynamic>, d['id'].toString()))
          .toList();

      final championships = championshipsList
          .map((d) => Championship.fromFirestore(d as Map<String, dynamic>, d['id'].toString()))
          .toList();

      return {
        'stadiums': stadiums,
        'teams': teams,
        'championships': championships,
      };
    } catch (e, stack) {
      VSPLogger.e('Global search error for term "$term"', e, stack);
      return {'stadiums': [], 'teams': [], 'championships': []};
    }
  }
}
