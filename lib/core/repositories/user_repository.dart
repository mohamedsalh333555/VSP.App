import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/logger_service.dart';
import '../utils/phone_utils.dart';
import '../../data/models.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<UserModel?> getUserByPhone(String phone) async {
    try {
      final normalizedPhone = PhoneUtils.normalize(phone);
      final snapshot = await _firestore
          .collection('users')
          .where('phone', isEqualTo: normalizedPhone)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return UserModel.fromFirestore(snapshot.docs.first.data());
    } catch (e) {
      VSPLogger.e('Error getting user by phone', e);
      return null;
    }
  }

  Future<List<UserModel>> getUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: ids)
          .get();
      
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc.data())).toList();
    } catch (e) {
      VSPLogger.e('Error getting users by IDs', e);
      return [];
    }
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      VSPLogger.e('Error updating user profile $userId', e);
    }
  }

  Future<void> updateUserModerationStatus(String userId, {required bool isSuspended, String? warningMessage}) async {
    try {
      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(userId);
      
      batch.update(userRef, {
        'isSuspended': isSuspended,
        if (warningMessage != null) 'lastWarning': warningMessage,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (warningMessage != null) {
        final notificationRef = userRef.collection('notifications').doc();
        batch.set(notificationRef, {
          'title': 'Safety Warning ⚠️',
          'body': warningMessage,
          'type': 'warning',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      VSPLogger.e('Error updating user moderation status', e);
    }
  }

  Future<bool> reportEntity({
    required String reporterId,
    required String targetId,
    required String targetType,
    required String reason,
    String? details,
  }) async {
    try {
      await _firestore.collection('reports').add({
        'reporterId': reporterId,
        'targetId': targetId,
        'targetType': targetType,
        'reason': reason,
        'details': details,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      VSPLogger.e('Error reporting entity', e);
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> getReportsStream() {
    return _firestore.collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Future<List<Booking>> getUnpaidBookingsForUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('isPaid', isEqualTo: false)
          .get();
      
      return snapshot.docs.map((doc) => Booking.fromFirestore(doc.data(), doc.id)).toList();
    } catch (e) {
      VSPLogger.e('Error fetching unpaid bookings for user $userId', e);
      return [];
    }
  }
}
