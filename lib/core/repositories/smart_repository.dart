import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../utils/vsp_feedback.dart';

/// Smart Repository with Local Caching and Paginated Queries
class SmartRepository {
 static const int pageSize = 20;
 final SupabaseClient _supabase = Supabase.instance.client;
 final Map<String, List<dynamic>> _cache = {};

 /// Paginated Championship Fetching with Cache
 Future<List<Championship>> getTournaments(
 BuildContext context, {
 int page = 0,
 bool refresh = false,
 }) async {
 final cacheKey = 'tournaments_page_$page';

 if (!refresh && _cache.containsKey(cacheKey)) {
 return (_cache[cacheKey] as List).cast<Championship>();
 }

 try {
 final offset = page * pageSize;
 final response = await _supabase
 .from('championships')
 .select()
 .range(offset, offset + pageSize - 1)
 .order('created_at', ascending: false);

 final tournaments = (response as List)
 .map((json) => Championship.fromFirestore(json, json['id'].toString()))
 .toList();

 _cache[cacheKey] = tournaments;
 return tournaments;
 } catch (e) {
 if (context.mounted) {
 VSPFeedback.showError(context, "خطأ في تحميل قائمة البطولات.");
 }
 return [];
 }
 }

 /// Autocomplete Pitch Search (Max 10 Results)
 Future<List<Map<String, dynamic>>> searchStadiums(String query) async {
 if (query.trim().isEmpty) return [];

 try {
 final response = await _supabase
 .from('stadiums')
 .select()
 .ilike('name', '%${query.trim()}%')
 .limit(10);

 return (response as List).cast<Map<String, dynamic>>();
 } catch (e) {
 debugPrint('Search Stadiums Error: $e');
 return [];
 }
 }

 /// Clear Repository Cache
 void clearCache() {
 _cache.clear();
 }
}
