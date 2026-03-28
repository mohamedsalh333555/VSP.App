import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models.dart';
import '../models/user_model.dart';
import '../config/app_config.dart';
import '../services/logger_service.dart';
import '../constants/egypt_governorates.dart';

class StadiumRepository {
  final FirebaseFirestore _firestore;

  StadiumRepository({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get all stadiums (with expanded limit)
  Stream<List<Stadium>> getStadiums({int limit = 50}) {
    Query query = _firestore.collection('stadiums');
    
    // Bypass verification check in demo mode so players can see stadiums
    if (!AppConfig.demoMode) {
      query = query.where('isVerified', isEqualTo: true);
    }
    
    return query
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Stadium.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get stadium by ID
  Future<Stadium?> getStadiumById(String stadiumId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('stadiums').doc(stadiumId).get();
      if (doc.exists) {
        return Stadium.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get raw stadium data for editing
  Future<Map<String, dynamic>?> getStadiumSnapshot(String stadiumId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('stadiums').doc(stadiumId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get stadiums for a specific owner
  Stream<List<Stadium>> getOwnerStadiums(String ownerId) {
     return _firestore
        .collection('stadiums')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Stadium.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Add new stadium (Owner)
  Future<String?> addStadium(Map<String, dynamic> stadiumData) async {
    try {
      // SECURITY HARDENING: Strip sensitive fields from generic creation
      final sanitizedData = Map<String, dynamic>.from(stadiumData);
      sanitizedData.remove('isVerified');
      sanitizedData.remove('createdAt');

      DocumentReference ref = await _firestore.collection('stadiums').add({
        ...sanitizedData,
        'isVerified': true, // Auto-verify for testing
        'createdAt': FieldValue.serverTimestamp(),
        'isBlocked': false,
        'name_lowercase': (sanitizedData['name'] ?? '').toString().toLowerCase(),
      });
      return ref.id;
    } catch (e) {
      debugPrint('Error adding stadium: Masked for security');
      return null;
    }
  }

  // SECURITY PATCH: Sanitize stadium updates to prevent hijacking verified status or owner identity.
  Future<bool> updateStadium(String stadiumId, Map<String, dynamic> data) async {
    try {
      final securedData = Map<String, dynamic>.from(data);
      // SECURITY: Prevents unauthorized verification bypass or stadium ownership theft
      securedData.remove('isVerified');
      securedData.remove('ownerId');
      securedData.remove('createdAt');
      
      await _firestore.collection('stadiums').doc(stadiumId).update(securedData);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Create stadium with named parameters (helper)
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
    Map<String, dynamic>? features,
  }) async {
    return await addStadium({
      'name': name,
      'location': location,
      'governorate': governorate,
      'pricePerHour': pricePerHour,
      'seatsCapacity': seatsCapacity,
      'imageUrl': imageUrl,
      'ownerId': ownerId,
      'notes': notes,
      'contractUrl': contractUrl,
      'ownerIdUrl': ownerIdUrl,
      'isVerified': true, // Auto-verify for testing
      'features': features ?? {},
    });
  }

  /// Fetch stadiums in batches of 10
  Future<Map<String, dynamic>> getStadiumsPaginated({
    int limit = 10,
    DocumentSnapshot? startAfter,
    String? governorate,
  }) async {
    try {
      Query query = _firestore.collection('stadiums');
      
      if (!AppConfig.demoMode) {
        query = query.where('isVerified', isEqualTo: true);
        query = query.where('isBlocked', isEqualTo: false);
      }

      if (governorate != null && governorate.isNotEmpty) {
        final String standardGov = EgyptGovernorates.resolveGoogleName(governorate);
        query = query.where('governorate', isEqualTo: standardGov);
      }
      
      query = query.orderBy('createdAt', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final items = snapshot.docs
          .map((doc) => Stadium.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      return {
        'items': items,
        'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      };
    } catch (e) {
      debugPrint('\n--- 🚨 FAILED TO FETCH STADIUMS 🚨 ---');
      debugPrint('If you see a Firebase Index URL below, click it to enable compound queries:');
      debugPrint('$e\n');
      return {'items': [], 'lastDoc': null};
    }
  }

  // Stadium Deletion Safeguard
  Future<bool> deleteStadium(String stadiumId) async {
    try {
      // 1. Get Upcoming Bookings
      final bookingSnap = await _firestore.collection('bookings')
          .where('stadiumId', isEqualTo: stadiumId)
          .where('status', isEqualTo: 'upcoming')
          .get();

      final batch = _firestore.batch();
      
      // 2. Cascade cancel bookings and Notify Players
      if (bookingSnap.docs.isNotEmpty) {
        for (var doc in bookingSnap.docs) {
          batch.update(doc.reference, {
            'status': 'cancelled_by_owner',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          final bookingData = doc.data();
          final userId = bookingData['createdByUserId'];
          if (userId != null) {
            final notificationRef = _firestore.collection('users').doc(userId).collection('notifications').doc();
            batch.set(notificationRef, {
              'title': 'Booking Cancelled 🏟️',
              'body': 'Your booking at ${bookingData['stadiumName']} was cancelled as the stadium is no longer available.',
              'type': 'cancelled_by_owner',
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
              'bookingId': doc.id,
            });
          }
        }
      }

      // 3. Mark Stadium as Deleted/Unverified
      batch.update(_firestore.collection('stadiums').doc(stadiumId), {
        'isVerified': false,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      VSPLogger.e('Error during stadium deletion cascade', e);
      return false;
    }
  }
  // ==================== PROMOTIONS ====================

  /// Stream of active promotions for marketing
  Stream<List<Promotion>> getPromotionsStream() {
    return _firestore
        .collection('promotions')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Promotion.fromFirestore(doc.data(), doc.id))
            .toList());
  }
}
