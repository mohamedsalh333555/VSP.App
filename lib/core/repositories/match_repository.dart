import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models.dart';
import '../services/analytics_service.dart';
import '../services/logger_service.dart';
import '../services/notification_handler.dart';
import 'notification_repository.dart';

class MatchRepository {
  final FirebaseFirestore _firestore;
  final NotificationRepository _notificationRepo;

  MatchRepository({FirebaseFirestore? firestore, NotificationRepository? notificationRepo})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationRepo = notificationRepo ?? NotificationRepository();

  // Get all matches (Live stream)
  Stream<List<Map<String, dynamic>>> getMatches() {
    return _firestore
        .collection('matches')
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }

  // OLD/Legacy Match Join - Transaction based
  Future<bool> joinMatch(String matchId, String userId) async {
    try {
      DocumentReference matchRef = _firestore.collection('matches').doc(matchId);
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot matchSnapshot = await transaction.get(matchRef);
        if (!matchSnapshot.exists) throw Exception('Match does not exist');
        Map<String, dynamic> matchData = matchSnapshot.data() as Map<String, dynamic>;
        List<dynamic> joinedPlayers = matchData['joinedPlayers'] ?? [];
        int remainingSlots = matchData['remainingSlots'] ?? 0;
        if (remainingSlots <= 0) throw Exception('Match is full');
        if (joinedPlayers.contains(userId)) throw Exception('Already joined');
        transaction.update(matchRef, {
          'joinedPlayers': FieldValue.arrayUnion([userId]),
          'remainingSlots': remainingSlots - 1,
        });
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> leaveMatch(String matchId, String userId) async {
    try {
      DocumentReference matchRef = _firestore.collection('matches').doc(matchId);
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot matchSnapshot = await transaction.get(matchRef);
        if (!matchSnapshot.exists) throw Exception('Match does not exist');
        Map<String, dynamic> matchData = matchSnapshot.data() as Map<String, dynamic>;
        int remainingSlots = matchData['remainingSlots'] ?? 0;
        transaction.update(matchRef, {
          'joinedPlayers': FieldValue.arrayRemove([userId]),
          'remainingSlots': remainingSlots + 1,
        });
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Stream<QuerySnapshot> getMatchesStream() {
    return _firestore.collection('matches').snapshots();
  }

  // --- PUBLIC MATCHES (Modern) ---

  Stream<List<Booking>> getPublicMatches() {
    final now = DateTime.now();
    // Simplified to bypass index requirements entirely while maintaining performance
    return _firestore
        .collection('bookings')
        .where('startTime', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('startTime', descending: false)
        .snapshots()
        .map<List<Booking>>((snapshot) {
          return snapshot.docs
              .map((doc) => Booking.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
              .where((b) {
                // Client-side filtering for everything to ensure zero index crashes
                final isConfirmed = b.status == BookingStatus.confirmed || 
                                   b.status == BookingStatus.upcoming;
                final isPublic = b.isPrivate == false;
                
                final max = b.maxPlayers > 0 ? b.maxPlayers : 10;
                final totalCapacity = max * 2;
                final hasSpace = b.currentPlayers < totalCapacity;
                
                return isConfirmed && isPublic && hasSpace;
              })
              .toList();
        });
  }

  Future<bool> joinPublicMatch(String bookingId, String userId) async {
    try {
      final docRef = _firestore.collection('bookings').doc(bookingId);
      String hostId = '';
      String stadiumName = '';
      String joiningUserName = 'A player';

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) throw 'Match not found';
        
        final data = doc.data() as Map<String, dynamic>;
        hostId = data['ownerId'] ?? data['createdByUserId'] ?? '';
        stadiumName = data['stadiumName'] ?? 'Match';
        final current = data['currentPlayers'] ?? 0;
        final max = data['maxPlayers'] ?? 0;
        final joined = List<String>.from(data['joinedUserIds'] ?? []);
        
        final totalFieldCapacity = max > 0 ? max * 2 : 10;
        if (current >= totalFieldCapacity) throw 'Match is full';
        if (joined.contains(userId)) throw 'Already joined';
        
        transaction.update(docRef, {
          'currentPlayers': FieldValue.increment(1),
          'joinedUserIds': FieldValue.arrayUnion([userId]),
        });
      });

      final finalDoc = await docRef.get();
      final finalData = finalDoc.data() as Map<String, dynamic>;
      final finalCurrent = finalData['currentPlayers'] ?? 0;
      final finalMax = finalData['maxPlayers'] ?? 0;
      final totalCapacity = finalMax > 0 ? finalMax * 2 : 10;
      final participantIds = List<String>.from(finalData['joinedUserIds'] ?? []);

      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          joiningUserName = userDoc.data()?['name'] ?? 'A player';
        }
      } catch (_) {}

      if (hostId.isNotEmpty && hostId != userId) {
        await NotificationHandler.notifyPlayerJoinedMatch(
          hostId: hostId,
          playerName: joiningUserName,
          stadiumName: stadiumName,
          bookingId: bookingId,
        );
      }

      if (finalCurrent >= totalCapacity) {
        await NotificationHandler.notifyMatchIsFull(
          playerIds: participantIds,
          stadiumName: stadiumName,
          bookingId: bookingId,
        );
      }

      AnalyticsService.logMatchJoined(bookingId, 'public');
      return true;
    } catch (e) {
      VSPLogger.e('Error joining public match', e);
      return false;
    }
  }

  Future<bool> leavePublicMatch(String bookingId, String userId) async {
    try {
      final docRef = _firestore.collection('bookings').doc(bookingId);
      String hostId = '';
      String stadiumName = '';
      String leavingUserName = 'A player';

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) throw 'Match not found';
        
        final data = doc.data() as Map<String, dynamic>;
        hostId = data['ownerId'] ?? data['createdByUserId'] ?? '';
        stadiumName = data['stadiumName'] ?? 'Match';
        final joined = List<String>.from(data['joinedUserIds'] ?? []);
        
        if (!joined.contains(userId)) throw 'Not a participant';
        
        transaction.update(docRef, {
          'currentPlayers': FieldValue.increment(-1),
          'joinedUserIds': FieldValue.arrayRemove([userId]),
        });
      });

      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
            leavingUserName = userDoc.data()?['name'] ?? 'A player';
        }
      } catch (_) {}

      if (hostId.isNotEmpty && hostId != userId) {
        await _notificationRepo.sendNotification(
          hostId,
          AppNotification(
            id: '',
            title: 'Player Left Match ⚠️',
            body: '$leavingUserName left your match at $stadiumName.',
            type: 'info',
            createdAt: DateTime.now(),
            bookingId: bookingId,
          ),
        );
      }
      return true;
    } catch (e) {
      VSPLogger.e('Error leaving public match', e);
      return false;
    }
  }

  Future<bool> removeParticipantFromPublicMatch(String bookingId, String userId) async {
    try {
      final docRef = _firestore.collection('bookings').doc(bookingId);
      String stadiumName = 'Match';

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) throw 'Match not found';
        
        final data = doc.data() as Map<String, dynamic>;
        stadiumName = data['stadiumName'] ?? 'Match';
        final joined = List<String>.from(data['joinedUserIds'] ?? []);
        
        if (!joined.contains(userId)) throw 'User is not a participant';
        
        transaction.update(docRef, {
          'currentPlayers': FieldValue.increment(-1),
          'joinedUserIds': FieldValue.arrayRemove([userId]),
        });
      });

      await _notificationRepo.sendNotification(
        userId,
        AppNotification(
          id: '',
          title: 'Match Participation Cancelled ❕',
          body: 'The host has removed you from the match at $stadiumName.',
          type: 'info',
          createdAt: DateTime.now(),
          bookingId: bookingId,
        ),
      );

      return true;
    } catch (e) {
      VSPLogger.e('Error removing participant from public match', e);
      return false;
    }
  }

  Future<bool> updatePublicMatchHostSpots(String bookingId, int newHostSpotsCount) async {
    try {
      final docRef = _firestore.collection('bookings').doc(bookingId);
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) throw 'Match not found';
        
        final data = doc.data() as Map<String, dynamic>;
        final joinedUserIds = List<String>.from(data['joinedUserIds'] ?? []);
        
        final newCurrentPlayers = joinedUserIds.length + newHostSpotsCount;
        final max = data['maxPlayers'] ?? 0;
        final totalFieldCapacity = max > 0 ? max * 2 : 10;
        
        if (newCurrentPlayers > totalFieldCapacity) {
          throw 'Exceeds stadium capacity';
        }
        
        transaction.update(docRef, {
          'currentPlayers': newCurrentPlayers,
        });
      });
      return true;
    } catch (e) {
      VSPLogger.e('Error updating host spots', e);
      return false;
    }
  }

  Future<Map<String, dynamic>> getPublicMatchesPaginated({
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final now = DateTime.now();
      Query query = _firestore
          .collection('bookings')
          .where('startTime', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('startTime', descending: false)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      
      final items = snapshot.docs
          .map((doc) => Booking.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .where((b) {
            final isConfirmed = b.status == BookingStatus.confirmed || 
                               b.status == BookingStatus.upcoming;
            final isPublic = b.isPrivate == false;
            final max = b.maxPlayers > 0 ? b.maxPlayers : 10;
            final hasSpace = b.currentPlayers < (max * 2);
            final isRightType = b.bookingType == BookingType.team || b.bookingType == BookingType.personal;
            return isConfirmed && isPublic && hasSpace && isRightType;
          }).toList();
      
      return {
        'items': items,
        'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      };
    } catch (e) {
      VSPLogger.e('Error fetching paginated matches', e);
      return {'items': [], 'lastDoc': null};
    }
  }
}
