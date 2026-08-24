import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models.dart';
import 'logger_service.dart';

class FastCacheService {
  static const String _stadiumsCacheKey = 'vsp_cached_stadiums_v1';
  static const String _teamsCacheKey = 'vsp_cached_teams_v1';

  // In-memory hot cache for instant 0.001s access
  static List<Stadium>? _memoryStadiums;

  /// Get cached stadiums instantly from memory or local disk
  static Future<List<Stadium>> getCachedStadiums() async {
    if (_memoryStadiums != null && _memoryStadiums!.isNotEmpty) {
      return _memoryStadiums!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_stadiumsCacheKey);
      if (rawJson == null || rawJson.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(rawJson);
      final List<Stadium> list = decoded
          .map((item) => Stadium.fromFirestore(Map<String, dynamic>.from(item as Map), item['id']?.toString() ?? ''))
          .toList();

      _memoryStadiums = list;
      return list;
    } catch (e) {
      VSPLogger.w('FastCache: failed to read cached stadiums: $e');
      return [];
    }
  }

  /// Synchronously get in-memory cached stadiums if already warmed up
  static List<Stadium> getMemoryStadiumsSync() {
    return _memoryStadiums ?? [];
  }

  /// Save stadiums to memory and local disk asynchronously
  static Future<void> cacheStadiums(List<Stadium> stadiums) async {
    if (stadiums.isEmpty) return;
    _memoryStadiums = List<Stadium>.from(stadiums);

    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = jsonEncode(stadiums.map((s) => s.toMap()).toList());
      await prefs.setString(_stadiumsCacheKey, serialized);
    } catch (e) {
      VSPLogger.w('FastCache: failed to persist stadiums to disk: $e');
    }
  }

  /// Check if local cache has stadiums
  static bool hasMemoryCache() {
    return _memoryStadiums != null && _memoryStadiums!.isNotEmpty;
  }

  /// Clear all cache
  static Future<void> clearAll() async {
    _memoryStadiums = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_stadiumsCacheKey);
      await prefs.remove(_teamsCacheKey);
    } catch (e) {
      debugPrint('Error clearing fast cache: $e');
    }
  }
}
