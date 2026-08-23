import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../models/user_model.dart';
import '../services/logger_service.dart';
import '../constants/egypt_governorates.dart';

class StadiumRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _formatTimeToHms(dynamic timeVal) {
    if (timeVal == null) return null;
    final str = timeVal.toString().trim();
    if (str.isEmpty) return null;
    final parts = str.split(':');
    if (parts.length == 1) {
      final h = int.tryParse(parts[0]) ?? 0;
      return '${h.toString().padLeft(2, '0')}:00:00';
    } else if (parts.length == 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
    } else if (parts.length >= 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return str;
  }

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

      // 💰 Subscription Plan Gate: Check max stadium limit for owner
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

      sanitizedData.remove('isVerified');
      sanitizedData.remove('is_verified');
      sanitizedData.remove('createdAt');
      sanitizedData.remove('created_at');

      final price = sanitizedData['pricePerHour'] ?? sanitizedData['price_per_hour'] ?? 0.0;
      final features = sanitizedData['features'] ?? {};
      final String sport = features['sportType'] ?? sanitizedData['sportType'] ?? sanitizedData['type'] ?? 'Football';
      final String originalDesc = sanitizedData['description'] ?? sanitizedData['notes'] ?? '';
      final String descWithSport = "$originalDesc|Sport:$sport";
      
      final ppt = sanitizedData['players_per_team'] ?? sanitizedData['seatsCapacity'] ?? 5;
      final tfc = sanitizedData['total_field_capacity'] ?? (ppt * 2);

      final imagesList = sanitizedData['images'] ?? (sanitizedData['imageUrl'] != null ? [sanitizedData['imageUrl']] : []);
      final firstImage = (imagesList is List && imagesList.isNotEmpty) ? imagesList.first : null;

      final bool isSplitShift = sanitizedData['isSplitShift'] == true ||
          sanitizedData['is_split_shift'] == true ||
          (features is Map && features['isSplitShift'] == true);

      dynamic rawBreakStart = sanitizedData['breakStartTime'] ??
          sanitizedData['break_start_time'] ??
          ((features is Map && features['breakTime'] is Map) ? features['breakTime']['start'] : null);
      dynamic rawBreakEnd = sanitizedData['breakEndTime'] ??
          sanitizedData['break_end_time'] ??
          ((features is Map && features['breakTime'] is Map) ? features['breakTime']['end'] : null);

      final pgData = {
        'name': sanitizedData['name'],
        'owner_id': sanitizedData['ownerId'] ?? sanitizedData['owner_id'],
        'description': descWithSport,
        'notes': sanitizedData['notes'] ?? '',
        'features': features,
        'opening_time': sanitizedData['openingTime'] ?? sanitizedData['opening_time'] ?? ((features is Map && features['workingHours'] is Map) ? features['workingHours']['start'] : null),
        'closing_time': sanitizedData['closingTime'] ?? sanitizedData['closing_time'] ?? ((features is Map && features['workingHours'] is Map) ? features['workingHours']['end'] : null),
        'is_split_shift': isSplitShift,
        'break_start_time': isSplitShift ? _formatTimeToHms(rawBreakStart) : null,
        'break_end_time': isSplitShift ? _formatTimeToHms(rawBreakEnd) : null,
        'players_per_team': ppt,
        'total_field_capacity': tfc,
        'governorate': sanitizedData['governorate'] ?? 'Cairo',
        'city': sanitizedData['area'] ?? sanitizedData['location'] ?? 'Cairo',
        'location': sanitizedData['address'] ?? sanitizedData['location'] ?? '',
        'price_per_hour': price,
        'base_price': sanitizedData['basePrice'] ?? sanitizedData['base_price'] ?? price,
        'images': imagesList,
        'image_url': sanitizedData['imageUrl'] ?? sanitizedData['image_url'] ?? firstImage,
        'is_verified': false, 
        'is_blocked': false,
        'is_deleted_by_owner': false,
        'rating': 0.0,
        'reviews_count': 0,
        'deposit_amount': sanitizedData['depositAmount'] ?? sanitizedData['deposit_amount'] ?? 0.0,
        'needs_deposit': sanitizedData['needsDeposit'] ?? sanitizedData['needs_deposit'] ?? false,
        'lat': sanitizedData['lat'],
        'lng': sanitizedData['lng'],
      };

      final response = await _supabase
          .from('stadiums')
          .insert(pgData)
          .select('id')
          .single();
          
      VSPLogger.i('✅ Stadium successfully added to Supabase: ${response['id']}');
      return response['id']?.toString();
    } catch (e, stack) {
      VSPLogger.e('❌ CRITICAL ERROR IN addStadium', e, stack);
      return null;
    }
  }

  // Update stadium
  Future<bool> updateStadium(String stadiumId, Map<String, dynamic> data) async {
    try {
      final securedData = Map<String, dynamic>.from(data);
      securedData.remove('ownerId');
      securedData.remove('owner_id');
      securedData.remove('createdAt');
      securedData.remove('created_at');

      final pgData = <String, dynamic>{};
      if (securedData.containsKey('name')) pgData['name'] = securedData['name'];
      if (securedData.containsKey('description') || securedData.containsKey('sportType') || securedData.containsKey('type')) {
        final String sport = securedData['sportType'] ?? securedData['type'] ?? 'Football';
        String desc = securedData['description'] ?? '';
        desc = desc.replaceAll(RegExp(r'\|Sport:[^|]*'), '').trim();
        pgData['description'] = '$desc|Sport:$sport';
      }
      if (securedData.containsKey('features')) {
        pgData['features'] = securedData['features'];
        final feat = securedData['features'];
        if (feat is Map && feat['workingHours'] is Map) {
          if (feat['workingHours']['start'] != null) pgData['opening_time'] = feat['workingHours']['start'];
          if (feat['workingHours']['end'] != null) pgData['closing_time'] = feat['workingHours']['end'];
        }
        if (feat is Map && feat.containsKey('isSplitShift')) {
          pgData['is_split_shift'] = feat['isSplitShift'] == true;
          if (feat['isSplitShift'] == true && feat['breakTime'] is Map) {
            pgData['break_start_time'] = _formatTimeToHms(feat['breakTime']['start']);
            pgData['break_end_time'] = _formatTimeToHms(feat['breakTime']['end']);
          } else if (feat['isSplitShift'] == false) {
            pgData['break_start_time'] = null;
            pgData['break_end_time'] = null;
          }
        }
      }
      if (securedData.containsKey('isSplitShift') || securedData.containsKey('is_split_shift')) {
        final bool isSplit = securedData['isSplitShift'] == true || securedData['is_split_shift'] == true;
        pgData['is_split_shift'] = isSplit;
        if (!isSplit) {
          pgData['break_start_time'] = null;
          pgData['break_end_time'] = null;
        }
      }
      if (securedData.containsKey('breakStartTime')) pgData['break_start_time'] = _formatTimeToHms(securedData['breakStartTime']);
      if (securedData.containsKey('break_start_time')) pgData['break_start_time'] = _formatTimeToHms(securedData['break_start_time']);
      if (securedData.containsKey('breakEndTime')) pgData['break_end_time'] = _formatTimeToHms(securedData['breakEndTime']);
      if (securedData.containsKey('break_end_time')) pgData['break_end_time'] = _formatTimeToHms(securedData['break_end_time']);
      if (securedData.containsKey('openingTime')) pgData['opening_time'] = securedData['openingTime'];
      if (securedData.containsKey('opening_time')) pgData['opening_time'] = securedData['opening_time'];
      if (securedData.containsKey('closingTime')) pgData['closing_time'] = securedData['closingTime'];
      if (securedData.containsKey('closing_time')) pgData['closing_time'] = securedData['closing_time'];
      if (securedData.containsKey('governorate')) pgData['governorate'] = securedData['governorate'];
      if (securedData.containsKey('address')) pgData['location'] = securedData['address'];
      if (securedData.containsKey('location')) pgData['location'] = securedData['location'];
      if (securedData.containsKey('pricePerHour')) pgData['price_per_hour'] = securedData['pricePerHour'];
      if (securedData.containsKey('price_per_hour')) pgData['price_per_hour'] = securedData['price_per_hour'];
      if (securedData.containsKey('basePrice')) pgData['base_price'] = securedData['basePrice'];
      if (securedData.containsKey('base_price')) pgData['base_price'] = securedData['base_price'];
      if (securedData.containsKey('images')) pgData['images'] = securedData['images'];
      if (securedData.containsKey('imageUrl')) pgData['image_url'] = securedData['imageUrl'];
      if (securedData.containsKey('image_url')) pgData['image_url'] = securedData['image_url'];
      if (securedData.containsKey('isBlocked')) pgData['is_blocked'] = securedData['isBlocked'];
      if (securedData.containsKey('is_blocked')) pgData['is_blocked'] = securedData['is_blocked'];
      if (securedData.containsKey('is_verified')) pgData['is_verified'] = securedData['is_verified'];
      if (securedData.containsKey('isVerified')) pgData['is_verified'] = securedData['isVerified'];
      if (securedData.containsKey('is_deleted_by_owner')) pgData['is_deleted_by_owner'] = securedData['is_deleted_by_owner'];
      if (securedData.containsKey('rating')) pgData['rating'] = securedData['rating'];
      if (securedData.containsKey('reviewsCount')) pgData['reviews_count'] = securedData['reviewsCount'];
      if (securedData.containsKey('reviews_count')) pgData['reviews_count'] = securedData['reviews_count'];
      if (securedData.containsKey('deposit_amount')) pgData['deposit_amount'] = securedData['deposit_amount'];
      if (securedData.containsKey('depositAmount')) pgData['deposit_amount'] = securedData['depositAmount'];
      if (securedData.containsKey('needs_deposit')) pgData['needs_deposit'] = securedData['needs_deposit'];
      if (securedData.containsKey('needsDeposit')) pgData['needs_deposit'] = securedData['needsDeposit'];
      if (securedData.containsKey('players_per_team')) pgData['players_per_team'] = securedData['players_per_team'];
      if (securedData.containsKey('total_field_capacity')) pgData['total_field_capacity'] = securedData['total_field_capacity'];
      if (securedData.containsKey('lat')) pgData['lat'] = securedData['lat'];
      if (securedData.containsKey('lng')) pgData['lng'] = securedData['lng'];

      // Keep base_price in sync with price_per_hour if modified
      if (pgData.containsKey('price_per_hour') && !pgData.containsKey('base_price')) {
        pgData['base_price'] = pgData['price_per_hour'];
      }

      if (pgData.isEmpty) return true;

      await _supabase.from('stadiums').update(pgData).eq('id', stadiumId);
      return true;
    } catch (e, stack) {
      VSPLogger.e('❌ CRITICAL ERROR IN updateStadium', e, stack);
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
          query = query.eq('governorate', standardGov);
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

  // Stadium Deletion Safeguard (Handles ON DELETE RESTRICT with soft-delete fallback)
  Future<bool> deleteStadium(String stadiumId) async {
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

  // 🛡️ Discovery and Search Geo-Matching: Database-Level Geodistance Query
  // Offloads GPS distance calculation and trigonometric sorting from client device to Supabase execution.
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
