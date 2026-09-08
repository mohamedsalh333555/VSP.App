import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/banner_model.dart';

/// Service for managing and retrieving dynamic promotional banners from Supabase.
class BannerService {
  static final BannerService _instance = BannerService._internal();
  factory BannerService() => _instance;
  BannerService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Cache of recorded impression IDs for the current session to avoid duplicate counts
  final Set<String> _recordedImpressions = {};

  /// Fetches all active and valid banners for a given placement.
  /// Sorted by [priority_order] ascending.
  Future<List<AppBanner>> getActiveBanners({String placement = 'home_slider'}) async {
    try {
      final response = await _supabase
          .from('banners')
          .select()
          .eq('is_active', true)
          .eq('placement', placement)
          .order('priority_order', ascending: true);

      final list = (response as List<dynamic>)
          .map((data) => AppBanner.fromJson(Map<String, dynamic>.from(data as Map)))
          .where((banner) => banner.isValidNow)
          .toList();

      return list;
    } catch (e) {
      debugPrint('[BannerService] Error fetching active banners: $e');
      return [];
    }
  }

  /// Real-time stream of active banners for a specific placement.
  Stream<List<AppBanner>> getActiveBannersStream({String placement = 'home_slider'}) {
    try {
      return _supabase
          .from('banners')
          .stream(primaryKey: ['id'])
          .eq('is_active', true)
          .order('priority_order', ascending: true)
          .map((list) {
            return list
                .where((map) => (map['placement'] ?? 'home_slider') == placement)
                .map((map) => AppBanner.fromJson(Map<String, dynamic>.from(map)))
                .where((banner) => banner.isValidNow)
                .toList();
          });
    } catch (e) {
      debugPrint('[BannerService] Error creating banners stream: $e');
      return Stream.value([]);
    }
  }

  /// Increments the view count for a banner.
  /// Deduplicated in-memory so an impression is recorded at most once per session per banner.
  Future<void> recordBannerImpression(String bannerId) async {
    if (bannerId.isEmpty || _recordedImpressions.contains(bannerId)) {
      return;
    }
    _recordedImpressions.add(bannerId);

    try {
      // 1. Try atomic RPC if defined in Supabase
      try {
        await _supabase.rpc('increment_banner_views', params: {'p_banner_id': bannerId});
        return;
      } catch (_) {
        // Fallback: Try with 'banner_id' param name
        try {
          await _supabase.rpc('increment_banner_views', params: {'banner_id': bannerId});
          return;
        } catch (_) {
          // Fallback: Direct increment query
        }
      }

      // 2. Direct fallback increment
      final current = await _supabase
          .from('banners')
          .select('views_count')
          .eq('id', bannerId)
          .maybeSingle();

      if (current != null) {
        final count = (current['views_count'] as int? ?? 0) + 1;
        await _supabase.from('banners').update({'views_count': count}).eq('id', bannerId);
      }
    } catch (e) {
      debugPrint('[BannerService] Failed to record banner impression: $e');
    }
  }

  /// Increments the click count for a banner when tapped by a user.
  Future<void> recordBannerClick(String bannerId) async {
    if (bannerId.isEmpty) return;

    try {
      // 1. Try atomic RPC if defined in Supabase
      try {
        await _supabase.rpc('increment_banner_clicks', params: {'p_banner_id': bannerId});
        return;
      } catch (_) {
        // Fallback: Try with 'banner_id' param name
        try {
          await _supabase.rpc('increment_banner_clicks', params: {'banner_id': bannerId});
          return;
        } catch (_) {
          // Fallback: Direct increment query
        }
      }

      // 2. Direct fallback increment
      final current = await _supabase
          .from('banners')
          .select('clicks_count')
          .eq('id', bannerId)
          .maybeSingle();

      if (current != null) {
        final count = (current['clicks_count'] as int? ?? 0) + 1;
        await _supabase.from('banners').update({'clicks_count': count}).eq('id', bannerId);
      }
    } catch (e) {
      debugPrint('[BannerService] Failed to record banner click: $e');
    }
  }
}
