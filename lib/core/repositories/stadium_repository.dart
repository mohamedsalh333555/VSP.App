import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../config/app_config.dart';
import '../services/logger_service.dart';
import '../constants/egypt_governorates.dart';

class StadiumRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get all stadiums (with expanded limit)
  Stream<List<Stadium>> getStadiums({int limit = 50}) {
    final query = _supabase.from('stadiums').stream(primaryKey: ['id']);
    
    if (!AppConfig.demoMode) {
      return query
          .eq('is_verified', true)
          .limit(limit)
          .map((list) => list
              .map((data) => Stadium.fromFirestore(data, data['id'].toString()))
              .toList());
    }
    
    return query
        .limit(limit)
        .map((list) => list
            .map((data) => Stadium.fromFirestore(data, data['id'].toString()))
            .toList());
  }

  // Get stadium by ID
  Future<Stadium?> getStadiumById(String stadiumId) async {
    try {
      final response = await _supabase
          .from('stadiums')
          .select()
          .eq('id', stadiumId)
          .maybeSingle();
      if (response != null) {
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
  Stream<List<Stadium>> getOwnerStadiums(String ownerId) {
     return _supabase
        .from('stadiums')
        .stream(primaryKey: ['id'])
        .eq('owner_id', ownerId)
        .map((list) => list
            .map((data) => Stadium.fromFirestore(data, data['id'].toString()))
            .toList());
  }

  // Add new stadium (Owner)
  Future<String?> addStadium(Map<String, dynamic> stadiumData) async {
    try {
      final sanitizedData = Map<String, dynamic>.from(stadiumData);
      sanitizedData.remove('isVerified');
      sanitizedData.remove('is_verified');
      sanitizedData.remove('createdAt');
      sanitizedData.remove('created_at');

      final price = sanitizedData['pricePerHour'] ?? sanitizedData['price_per_hour'] ?? 0.0;
      final features = sanitizedData['features'] ?? {};
      final String sport = features['sportType'] ?? sanitizedData['sportType'] ?? sanitizedData['type'] ?? 'Football';
      final String originalDesc = sanitizedData['description'] ?? sanitizedData['notes'] ?? '';
      final String descWithSport = '$originalDesc|Sport:$sport';

      final pgData = {
        'name': sanitizedData['name'],
        'owner_id': sanitizedData['ownerId'] ?? sanitizedData['owner_id'],
        'description': descWithSport,
        'governorate': sanitizedData['governorate'] ?? 'Cairo',
        'city': sanitizedData['area'] ?? sanitizedData['location'] ?? 'Cairo',
        'location': sanitizedData['address'] ?? sanitizedData['location'] ?? '',
        'price_per_hour': price,
        'base_price': sanitizedData['basePrice'] ?? sanitizedData['base_price'] ?? price,
        'images': sanitizedData['images'] ?? (sanitizedData['imageUrl'] != null ? [sanitizedData['imageUrl']] : []),
        'is_verified': true, // Auto-verify for testing
        'is_blocked': false,
        'deposit_amount': sanitizedData['depositAmount'] ?? sanitizedData['deposit_amount'] ?? 0.0,
        'needs_deposit': sanitizedData['needsDeposit'] ?? sanitizedData['needs_deposit'] ?? false,
      };

      final response = await _supabase
          .from('stadiums')
          .insert(pgData)
          .select('id')
          .single();
      
      return response['id']?.toString();
    } catch (e) {
      debugPrint('Error adding stadium: $e');
      return null;
    }
  }

  // Update stadium
  Future<bool> updateStadium(String stadiumId, Map<String, dynamic> data) async {
    try {
      final securedData = Map<String, dynamic>.from(data);
      securedData.remove('isVerified');
      securedData.remove('is_verified');
      securedData.remove('ownerId');
      securedData.remove('owner_id');
      securedData.remove('createdAt');
      securedData.remove('created_at');

      final pgData = <String, dynamic>{};
      if (securedData.containsKey('name')) pgData['name'] = securedData['name'];
      if (securedData.containsKey('description') || securedData.containsKey('sportType') || securedData.containsKey('type')) {
        final String sport = securedData['sportType'] ?? securedData['type'] ?? 'Football';
        final String desc = securedData['description'] ?? '';
        pgData['description'] = '$desc|Sport:$sport';
      }
      if (securedData.containsKey('governorate')) pgData['governorate'] = securedData['governorate'];
      if (securedData.containsKey('address')) pgData['location'] = securedData['address'];
      if (securedData.containsKey('location')) pgData['location'] = securedData['location'];
      if (securedData.containsKey('pricePerHour')) pgData['price_per_hour'] = securedData['pricePerHour'];
      if (securedData.containsKey('price_per_hour')) pgData['price_per_hour'] = securedData['price_per_hour'];
      if (securedData.containsKey('basePrice')) pgData['base_price'] = securedData['basePrice'];
      if (securedData.containsKey('base_price')) pgData['base_price'] = securedData['base_price'];
      if (securedData.containsKey('images')) pgData['images'] = securedData['images'];
      if (securedData.containsKey('isBlocked')) pgData['is_blocked'] = securedData['isBlocked'];
      if (securedData.containsKey('is_blocked')) pgData['is_blocked'] = securedData['is_blocked'];
      if (securedData.containsKey('rating')) pgData['rating'] = securedData['rating'];
      if (securedData.containsKey('reviewsCount')) pgData['reviews_count'] = securedData['reviewsCount'];
      if (securedData.containsKey('reviews_count')) pgData['reviews_count'] = securedData['reviews_count'];
      if (securedData.containsKey('deposit_amount')) pgData['deposit_amount'] = securedData['deposit_amount'];
      if (securedData.containsKey('depositAmount')) pgData['deposit_amount'] = securedData['depositAmount'];
      if (securedData.containsKey('needs_deposit')) pgData['needs_deposit'] = securedData['needs_deposit'];
      if (securedData.containsKey('needsDeposit')) pgData['needs_deposit'] = securedData['needsDeposit'];
      if (securedData.containsKey('players_per_team')) pgData['players_per_team'] = securedData['players_per_team'];
      if (securedData.containsKey('total_field_capacity')) pgData['total_field_capacity'] = securedData['total_field_capacity'];

      // Keep base_price in sync with price_per_hour if modified
      if (pgData.containsKey('price_per_hour') && !pgData.containsKey('base_price')) {
        pgData['base_price'] = pgData['price_per_hour'];
      }

      if (pgData.isEmpty) return true;

      await _supabase.from('stadiums').update(pgData).eq('id', stadiumId);
      return true;
    } catch (e) {
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
    required String ownerId,
    String notes = '',
    String? governorate,
    String? contractUrl,
    String? ownerIdUrl,
    double depositAmount = 0.0,
    bool needsDeposit = false,
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
      'ownerId': ownerId,
      'notes': notes,
      'contractUrl': contractUrl,
      'ownerIdUrl': ownerIdUrl,
      'isVerified': true,
      'features': features ?? {},
    });
  }

  /// Fetch stadiums in batches
  Future<Map<String, dynamic>> getStadiumsPaginated({
    int limit = 10,
    dynamic startAfter,
    String? governorate,
  }) async {
    try {
      dynamic query = _supabase.from('stadiums').select();
      
      if (!AppConfig.demoMode) {
        query = query.eq('is_verified', true);
        query = query.eq('is_blocked', false);
      }

      if (governorate != null && governorate.isNotEmpty) {
        final String? standardGov = EgyptGovernorates.resolveGoogleName(governorate);
        if (standardGov != null) {
          query = query.eq('governorate', standardGov);
        }
      }
      
      query = query.order('created_at', ascending: false);

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
      return {'items': [], 'lastDoc': null};
    }
  }

  // Stadium Deletion Safeguard via PostgreSQL cascade delete
  Future<bool> deleteStadium(String stadiumId) async {
    try {
      // CASCADE option on DB triggers handles associated bookings cancellation and notifications
      await _supabase.from('stadiums').delete().eq('id', stadiumId);
      return true;
    } catch (e) {
      VSPLogger.e('Error during stadium deletion cascade', e);
      return false;
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
