import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/logger_service.dart';

class ReportRepository {
  final FirebaseFirestore _firestore;

  ReportRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

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
}
