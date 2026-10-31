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
          .eq('is_verified', true)
          .eq('is_blocked', false)
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
              if (userModel.maxStadiums <= 1) {
                throw Exception(
                    'حسابك المجاني يدعم ملعباً واحداً فقط. اشترك في Pro لإضافة حتى 3 ملاعب.'
                );
              } else {
                throw Exception(
                    'وصلت للحد الأقصى لعدد الملاعب المسموح به في حسابك (${userModel.maxStadiums} ملاعب).'
                );
              }
            }
          }
        } catch (e) {
          if (e.toString().contains('باقتك') || e.toString().contains('الحد الأقصى')) rethrow;
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
      if (e.toString().contains('باقتك') || e.toString().contains('الحد الأقصى')) {
        rethrow;
      }
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
      'isVerified': false,
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
    List<String>? sportTypes,
    List<String>? pitchSizes,
    double? minPrice,
    double? maxPrice,
    bool? noDepositOnly,
    List<String>? amenities,
    String? quickFilter,
    String? floorType,
    String? searchQuery,
    String? sortBy,
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
      final normalizedSports = (sportTypes ?? const <String>[])
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && s != 'All')
          .toList();
      if (normalizedSports.isNotEmpty) {
        final sportExpressions = normalizedSports.map((sport) {
          final safeSport = sport.replaceAll(RegExp(r'[%,_(),|]'), ' ').trim();
          return 'description.ilike.%|Sport:$safeSport%,notes.ilike.%|Sport:$safeSport%';
        }).join(',');
        query = query.or(sportExpressions);
      } else if (sportType != null && sportType.isNotEmpty && sportType != 'All') {
        final safeSport = sportType.replaceAll(RegExp(r'[%,_(),|]'), ' ').trim();
        query = query.or(
          'description.ilike.%|Sport:$safeSport%,notes.ilike.%|Sport:$safeSport%',
        );
      }

      // 3. Pitch Size Filter
      final normalizedSizes = (pitchSizes ?? const <String>[])
          .map((value) => int.tryParse(RegExp(r'\d+').firstMatch(value)?.group(0) ?? ''))
          .whereType<int>()
          .toSet()
          .toList();
      if (normalizedSizes.isNotEmpty) {
        query = query.inFilter('players_per_team', normalizedSizes);
      } else if (pitchSize != null && pitchSize.isNotEmpty && pitchSize != 'All') {
        final playerCount = int.tryParse(RegExp(r'\d+').firstMatch(pitchSize)?.group(0) ?? '');
        if (playerCount != null) query = query.eq('players_per_team', playerCount);
      }

      // 3b. Floor type and text search are applied before pagination.
      final cleanFloorType = floorType?.trim() ?? '';
      if (cleanFloorType.isNotEmpty && cleanFloorType != 'All') {
        query = query.ilike('features->>floorType', '%$cleanFloorType%');
      }
      final cleanSearch = (searchQuery ?? '')
          .trim()
          .replaceAll(RegExp(r'[%_,()|]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ');
      if (cleanSearch.isNotEmpty) {
        query = query.or(
          'name.ilike.%$cleanSearch%,location.ilike.%$cleanSearch%,'
          'city.ilike.%$cleanSearch%,governorate.ilike.%$cleanSearch%',
        );
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
        query = query.or('needs_deposit.eq.false,deposit_amount.lte.0');
      }

      if (quickFilter == 'night_shift') {
        // closing_time is a PostgreSQL TIME column, not text.
        query = query.or(
          'closing_time.lt.06:00:00,'
          'features->workingHours->>end.ilike.%AM%,'
          'features->workingHours->>end.ilike.%صباحاً%,'
          'features->workingHours->>end.ilike.%00:%,'
          'features->workingHours->>end.ilike.%01:%,'
          'features->workingHours->>end.ilike.%02:%,'
          'features->workingHours->>end.ilike.%03:%,'
          'features->workingHours->>end.ilike.%04:%,'
          'features->workingHours->>end.ilike.%05:%',
        );
      } else if (quickFilter == 'no_deposit' && noDepositOnly != true) {
        query = query.or('needs_deposit.eq.false,deposit_amount.lte.0');
      }

      // Apply each selected amenity before range pagination.
      for (final amenity in amenities ?? const <String>[]) {
        final expression = _amenityOrExpression(amenity);
        if (expression == null) throw ArgumentError('Unsupported stadium amenity filter');
        query = query.or(expression);
      }
      
      switch (sortBy) {
        case 'priceLowToHigh':
          query = query.order('price_per_hour', ascending: true);
          break;
        case 'priceHighToLow':
          query = query.order('price_per_hour', ascending: false);
          break;
        case 'topRated':
          query = query.order('rating', ascending: false);
          break;
        default:
          query = query
              .order('is_featured', ascending: false)
              .order('created_at', ascending: false);
      }

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
      rethrow;
    }
  }

  String? _amenityOrExpression(String amenity) {
    switch (amenity.trim().toLowerCase()) {
      case 'دش وحمام':
      case 'showers & baths':
        return 'features->>bathOption.eq.Yes,features->>hasShower.eq.true,features->>shower.eq.true';
      case 'غرف تغيير ملابس':
      case 'changing rooms':
        return 'features->>changingRoom.eq.true,features->>changingRooms.eq.true,features->>hasChangingRooms.eq.true';
      case 'كافتيريا ومشروبات':
      case 'cafeteria & drinks':
        return 'features->>cafeteria.gt.0,features->>cafeteria.eq.true,features->>hasCafeteria.eq.true';
      case 'جراج سيارات':
      case 'garage & parking':
        return 'features->>garage.eq.true,features->>hasGarage.eq.true,features->>parking.eq.true';
      case 'مقاعد':
      case 'spectator seats':
        return 'features->>hasSeats.eq.true,features->>seats.gt.0';
      default:
        return null;
    }
  }

  // Stadium deletion is server-authoritative and always preserves operational history.
  Future<bool> deleteStadium(String stadiumId) async {
    try {
      final result = await _supabase.rpc(
        'delete_stadium_for_owner',
        params: {'p_stadium_id': stadiumId},
      );
      return result is Map && result['success'] == true;
    } catch (e) {
      VSPLogger.e('Error deleting stadium', e);
      rethrow;
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
          onTimeout: (sink) => sink.addError(StateError('stadium_stream_timeout')),
        );
  }

  /// Stream reviews for a stadium
  Stream<List<Map<String, dynamic>>> streamReviews(String stadiumId) {
    return _supabase
        .from('reviews')
        .stream(primaryKey: ['id'])
        .eq('stadium_id', stadiumId)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) => sink.addError(StateError('stadium_reviews_stream_timeout')),
        )
        .map((list) {
          final sorted = List<Map<String, dynamic>>.from(list);
          sorted.sort((a, b) => DateTime.parse(b['created_at'].toString())
              .compareTo(DateTime.parse(a['created_at'].toString())));
          return sorted;
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
    final response = await _supabase.rpc('submit_stadium_review_atomic', params: {
      'p_stadium_id': stadiumId,
      'p_user_id': userId,
      'p_user_name': userName,
      'p_user_image_url': userImageUrl,
      'p_rating': rating.round(),
      'p_comment': comment,
    });
    if (response is Map && response['success'] == false) {
      throw Exception(response['error']?.toString() ?? 'review_submission_failed');
    }
    return response;
  }

  /// Fetch multiple stadiums by their IDs (e.g. for Favorites)
  Future<List<Stadium>> getStadiumsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final res = await _supabase
          .from('stadiums')
          .select()
          .inFilter('id', ids)
          .eq('is_deleted_by_owner', false)
          .eq('is_verified', true)
          .eq('is_blocked', false);
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
      rethrow;
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
