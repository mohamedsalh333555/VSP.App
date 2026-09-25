import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../constants/egypt_governorates.dart';
import '../models/user_model.dart';
import '../services/logger_service.dart';
import 'stadium/stadium_payload_builder.dart';

class StadiumRepository {
  SupabaseClient get _supabase => Supabase.instance.client;

  // Get all verified stadiums with server-side filtering
  Stream<List<Stadium>> getStadiums({int limit = 50}) {
    return _supabase
        .from('stadiums')
        .stream(primaryKey: ['id'])
        .eq('is_deleted_by_owner', false)
        .limit(limit)
        .map((list) => list
            .map((data) => Stadium.fromFirestore(data, data['id'].toString()))
            .where((stadium) => stadium.isVerified && !stadium.isBlocked)
            .toList());
  }

  // Get stadium by ID
  Future<Stadium?> getStadiumById(String stadiumId) async {
    try {
      final response = await _supabase
          .from('stadiums')
          .select()
          .eq('id', stadiumId)
          .eq('is_deleted_by_owner', false)
          .maybeSingle();
      if (response != null && response['is_deleted_by_owner'] != true) {
        return Stadium.fromFirestore(response, response['id'].toString());
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get raw stadium data for editing
  Future<Map<String, dynamic>?> getStadiumSnapshot(String stadiumId) async {
    try {
      final response = await _supabase
          .from('stadiums')
          .select()
          .eq('id', stadiumId)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  // Get stadiums for a specific owner
  Stream<List<Stadium>> getOwnerStadiums(String ownerId) async* {
    final cleanOwnerId = ownerId.trim();
    if (cleanOwnerId.isEmpty) {
      yield <Stadium>[];
      return;
    }

    // 1. Immediate REST API fetch for instant UI load
    try {
      final response = await _supabase
          .from('stadiums')
          .select()
          .eq('owner_id', cleanOwnerId)
          .eq('is_deleted_by_owner', false)
          .order('created_at', ascending: false);

      final initialList = (response as List)
          .map((data) => Stadium.fromFirestore(data as Map<String, dynamic>, data['id'].toString()))
          .toList();
      yield initialList;
    } catch (e) {
      VSPLogger.w('Initial REST fetch for owner stadiums notice: $e');
    }

    // 2. Realtime Stream updates with error handling
    yield* _supabase
        .from('stadiums')
        .stream(primaryKey: ['id'])
        .eq('owner_id', cleanOwnerId)
        .map((list) => list
            .where((data) => data['is_deleted_by_owner'] != true)
            .map((data) => Stadium.fromFirestore(data, data['id'].toString()))
            .toList())
        .handleError((error) {
      VSPLogger.w('Realtime stream error for owner stadiums (handled): $error');
      return <Stadium>[];
    });
  }

  // Add new stadium (Owner)
  Future<String?> addStadium(Map<String, dynamic> stadiumData) async {
    try {
      final sanitizedData = Map<String, dynamic>.from(stadiumData);
      final String ownerId = sanitizedData['ownerId'] ?? sanitizedData['owner_id'] ?? '';

      // Subscription Plan Gate: Check max stadium limit for owner
      if (ownerId.isNotEmpty) {
        try {
          final userDoc = await _supabase.from('users').select().eq('id', ownerId).maybeSingle();
          if (userDoc != null) {
            final userModel = UserModel.fromFirestore(userDoc);
            final existingStadiums = await _supabase
                .from('stadiums')
                .select('id')
                .eq('owner_id', ownerId)
                .eq('is_deleted_by_owner', false);
            final currentCount = (existingStadiums as List).length;
            if (currentCount >= userModel.maxStadiums) {
              throw Exception(
                  'وصلت للحد الأقصى للملاعب في باقتك الحالية (${userModel.maxStadiums} ملعب). يرجى الترقية لإضافة ملاعب أخرى.'
              );
            }
          }
        } catch (e) {
          if (e.toString().contains('الحد الأقصى')) rethrow;
          VSPLogger.w('Skip stadium count validation error: $e');
        }
      }

      final pgData = StadiumPayloadBuilder.buildInsertPayload(sanitizedData);

      final response = await _supabase
          .from('stadiums')
          .insert(pgData)
          .select('id')
          .single();
      
      VSPLogger.i(' Stadium successfully added to Supabase: ${response['id']}');
      return response['id']?.toString();
    } catch (e, stack) {
      VSPLogger.e(' CRITICAL ERROR IN addStadium', e, stack);
      return null;
    }
  }

  // Update stadium
  Future<bool> updateStadium(String stadiumId, Map<String, dynamic> data) async {
    try {
      final pgData = StadiumPayloadBuilder.buildUpdatePayload(data);

      if (pgData.isEmpty) return true;

      // Every owner edit reopens review. This is intentionally conservative because
      // the wizard submits the full stadium record, including pricing/hours/location.
      pgData['is_verified'] = false;
      final response = await _supabase
          .from('stadiums')
          .update(pgData)
          .eq('id', stadiumId)
          .select('id, is_verified')
          .maybeSingle();
      return response != null;
    } catch (e, stack) {
      VSPLogger.e(' CRITICAL ERROR IN updateStadium', e, stack);
      return false;
    }
  }
  
  // Create stadium helper
  Future<String?> createStadium({
    required String name,
    required String location,
    required double pricePerHour,
    required int seatsCapacity,
    required String imageUrl,
    List<String>? images,
    required String ownerId,
    String notes = '',
    String? governorate,
    String? contractUrl,
    String? ownerIdUrl,
    double depositAmount = 0.0,
    bool needsDeposit = false,
    double? lat,
    double? lng,
    Map<String, dynamic>? features,
  }) async {
    return await addStadium({
      'name': name,
      'location': location,
      'governorate': governorate,
      'pricePerHour': pricePerHour,
      'seatsCapacity': seatsCapacity,
      'depositAmount': depositAmount,
      'needsDeposit': needsDeposit,
      'imageUrl': imageUrl,
      'images': images ?? (imageUrl.isNotEmpty ? [imageUrl] : []),
      'ownerId': ownerId,
      'notes': notes,
      'contractUrl': contractUrl,
      'ownerIdUrl': ownerIdUrl,
      'lat': lat,
      'lng': lng,
      'isVerified': true,
      'features': features ?? {},
    });
  }

  /// Fetch stadiums in batches with Server-Side SQL Filtering
  Future<Map<String, dynamic>> getStadiumsPaginated({
    int limit = 10,
    dynamic startAfter,
    String? governorate,
    String? sportType,
    String? pitchSize,
    double? minPrice,
    double? maxPrice,
    bool? noDepositOnly,
  }) async {
    try {
      dynamic query = _supabase
          .from('stadiums')
          .select()
          .eq('is_verified', true)
          .eq('is_blocked', false)
          .eq('is_deleted_by_owner', false);

      // 1. Governorate Filter
      if (governorate != null && governorate.isNotEmpty && governorate != 'All') {
        final String? standardGov = EgyptGovernorates.resolveGoogleName(governorate);
        if (standardGov != null) {
          final String arGov = EgyptGovernorates.governorateToArabic[standardGov] ?? standardGov;
          query = query.or('governorate.eq.$standardGov,governorate.eq.$arGov');
        }
      }

      // 2. Sport Type Filter
      if (sportType != null && sportType.isNotEmpty && sportType != 'All') {
        query = query.or('type.ilike.%$sportType%,description.ilike.%|Sport:$sportType%');
      }

      // 3. Pitch Size Filter
      if (pitchSize != null && pitchSize.isNotEmpty) {
        query = query.eq('size', pitchSize);
      }

      // 4. Price Range Filter
      if (minPrice != null && minPrice > 0) {
        query = query.gte('price_per_hour', minPrice);
      }
      if (maxPrice != null && maxPrice > 0) {
        query = query.lte('price_per_hour', maxPrice);
      }

      // 5. No Deposit Filter
      if (noDepositOnly == true) {
        query = query.eq('needs_deposit', false);
      }
      
      query = query
          .order('is_featured', ascending: false)
          .order('created_at', ascending: false);

      final int startIndex = (startAfter is int) ? startAfter : 0;
      final int endIndex = startIndex + limit - 1;
      
      final response = await query.range(startIndex, endIndex);
      final items = (response as List)
          .map((doc) => Stadium.fromFirestore(doc as Map<String, dynamic>, doc['id'].toString()))
          .toList();
      
      return {
        'items': items,
        'lastDoc': startIndex + items.length,
      };
    } catch (e) {
      VSPLogger.e('FAILED TO FETCH STADIUMS', e);
      return {'items': <Stadium>[], 'lastDoc': null};
    }
  }

  // Stadium Deletion Safeguard (Checks active bookings, reviews cleanup, hard/soft delete)
  Future<bool> deleteStadium(String stadiumId) async {
    final now = DateTime.now().toUtc();
    final startOfTodayUtc = DateTime.utc(now.year, now.month, now.day).toIso8601String();

    // Business Rule: Block deletion if active bookings exist today or in the future
    final activeBookingsCheck = await _supabase
        .from('bookings')
        .select('id')
        .eq('stadium_id', stadiumId)
        .neq('status', 'cancelled')
        .gte('start_time', startOfTodayUtc);

    if ((activeBookingsCheck as List).isNotEmpty) {
      throw Exception('active_bookings_exist');
    }

    // Clean up optional records (reviews)
    try {
      await _supabase.from('reviews').delete().eq('stadium_id', stadiumId);
    } catch (e) {
      VSPLogger.w('Pre-delete cleanup warning: $e');
    }

    try {
      // 1. Attempt Hard Delete (Permanent DB Removal)
      await _supabase.from('stadiums').delete().eq('id', stadiumId);
      return true;
    } catch (e) {
      VSPLogger.w('Hard delete failed (e.g. FK RESTRICT due to bookings). Falling back to soft-delete: $e');
      try {
        // 2. Fallback Soft-Delete if DB foreign key constraint prevents hard delete
        await _supabase
            .from('stadiums')
            .update({
              'is_deleted_by_owner': true,
              'is_verified': false,
              'is_blocked': true,
            })
            .eq('id', stadiumId);
        return true;
      } catch (softErr) {
        VSPLogger.e('Error during stadium soft deletion fallback', softErr);
        return false;
      }
    }
  }

  /// Check if owner still has active non-deleted stadiums
  Future<bool> checkOwnerHasRemainingStadiums(String ownerId) async {
    try {
      final remaining = await _supabase
          .from('stadiums')
          .select('id')
          .eq('owner_id', ownerId)
          .neq('is_deleted_by_owner', true);
      return (remaining as List).isNotEmpty;
    } catch (e, stack) {
      VSPLogger.e('Error checking remaining stadiums for $ownerId', e, stack);
      return false;
    }
  }

  /// Stream single stadium raw records for realtime details
  Stream<List<Map<String, dynamic>>> streamStadiumRaw(String stadiumId) {
    return _supabase
        .from('stadiums')
        .stream(primaryKey: ['id'])
        .eq('id', stadiumId)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) => sink.add([]),
        )
        .handleError((e) {
          VSPLogger.w('Handled realtime error in stadium details stream: $e');
        });
  }

  /// Stream reviews for a stadium
  Stream<List<Map<String, dynamic>>> streamReviews(String stadiumId) {
    return _supabase
        .from('reviews')
        .stream(primaryKey: ['id'])
        .eq('stadium_id', stadiumId)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) => sink.add([]),
        )
        .map((list) {
          final sorted = List<Map<String, dynamic>>.from(list);
          sorted.sort((a, b) => DateTime.parse(b['created_at'].toString())
              .compareTo(DateTime.parse(a['created_at'].toString())));
          return sorted;
        })
        .handleError((e) {
          VSPLogger.w('Handled realtime error in stadium reviews stream: $e');
        });
  }

  /// Submit stadium review atomic RPC
  Future<dynamic> submitStadiumReviewAtomic({
    required String stadiumId,
    required String userId,
    required String userName,
    required String userImageUrl,
    required double rating,
    required String comment,
  }) async {
    return _supabase.rpc('submit_stadium_review_atomic', params: {
      'p_stadium_id': stadiumId,
      'p_user_id': userId,
      'p_user_name': userName,
      'p_user_image_url': userImageUrl,
      'p_rating': rating,
      'p_comment': comment,
    });
  }

  /// Fetch multiple stadiums by their IDs (e.g. for Favorites)
  Future<List<Stadium>> getStadiumsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final res = await _supabase
          .from('stadiums')
          .select()
          .inFilter('id', ids);
      return (res as List)
          .map((d) => Stadium.fromFirestore(d as Map<String, dynamic>, d['id'].toString()))
          .toList();
    } catch (e, stack) {
      VSPLogger.e('Error fetching stadiums by IDs: $ids', e, stack);
      return [];
    }
  }

  // Discovery and Search Geo-Matching: Database-Level Geodistance Query
  Future<List<Stadium>> fetchNearbyStadiums(double lat, double lng, {int limit = 10}) async {
    try {
      final response = await _supabase.rpc('get_nearby_stadiums', params: {
        'user_lat': lat,
        'user_lng': lng,
        'max_limit': limit,
      });
      final List<dynamic> list = response as List? ?? [];
      return list
          .map((data) => Stadium.fromFirestore(data as Map<String, dynamic>, data['id'].toString()))
          .toList();
    } catch (e) {
      VSPLogger.e('FAILED TO FETCH NEARBY STADIUMS', e);
      return [];
    }
  }

  /// Stream of active promotions for marketing
  Stream<List<Promotion>> getPromotionsStream() {
    return _supabase
        .from('promotions')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .map((list) => list
            .map((doc) => Promotion.fromFirestore(doc, doc['id'].toString()))
            .toList());
  }
}
