import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import '../utils/elo_calculator.dart';
import '../services/analytics_service.dart';
import '../services/logger_service.dart';
import 'notification_handler.dart';
import '../../data/models.dart';
import '../config/app_config.dart';
import '../utils/phone_utils.dart';

class DatabaseService {
  final FirebaseFirestore _firestore;

  DatabaseService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ==================== USERS ====================

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
      // Note: whereIn is limited to 30 items in recent Firestore SDKs, 
      // which is plenty for a 12-member team.
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: ids)
          .get();
      
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting users by IDs: $e');
      return [];
    }
  }

  // ==================== MATCHES ====================
  
  // Get all matches
  Stream<List<Map<String, dynamic>>> getMatches() {
    return _firestore
        .collection('matches')
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }

  // Join a match
  Future<bool> joinMatch(String matchId, String userId) async {
    try {
      DocumentReference matchRef = _firestore.collection('matches').doc(matchId);
      
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot matchSnapshot = await transaction.get(matchRef);
        
        if (!matchSnapshot.exists) {
          throw Exception('Match does not exist');
        }

        Map<String, dynamic> matchData = matchSnapshot.data() as Map<String, dynamic>;
        List<dynamic> joinedPlayers = matchData['joinedPlayers'] ?? [];
        int remainingSlots = matchData['remainingSlots'] ?? 0;

        if (remainingSlots <= 0) {
          throw Exception('Match is full');
        }

        if (joinedPlayers.contains(userId)) {
          throw Exception('Already joined');
        }

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

  // Leave a match
  Future<bool> leaveMatch(String matchId, String userId) async {
    try {
      DocumentReference matchRef = _firestore.collection('matches').doc(matchId);
      
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot matchSnapshot = await transaction.get(matchRef);
        
        if (!matchSnapshot.exists) {
          throw Exception('Match does not exist');
        }

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

  // ==================== BOOKINGS ====================
  
  // Get bookings for owner
  Stream<List<Map<String, dynamic>>> getOwnerBookings(String ownerId) {
    return _firestore
        .collection('bookings')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }

  // Get stadiums for owner
  Stream<List<Stadium>> getOwnerStadiums(String ownerId) {
    return _firestore
        .collection('stadiums')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Stadium.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Create booking
  Future<String?> createBooking(Map<String, dynamic> bookingData) async {
    try {
      DocumentReference ref = await _firestore.collection('bookings').add({
        ...bookingData,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Save In-App Notification
      final notification = AppNotification(
        id: '', 
        title: 'Booking Confirmed!', 
        body: 'You successfully booked ${bookingData['stadiumName']}.', 
        type: 'info', 
        createdAt: DateTime.now(), 
        bookingId: ref.id,
      );
      await _firestore.collection('users').doc(bookingData['createdByUserId']).collection('notifications').add(notification.toFirestore());

      // Notify Owner
      if (bookingData['ownerId'] != null) {
        final ownerNotification = AppNotification(
          id: '',
          title: 'New Booking Received! 💰',
          body: '${bookingData['playerTeamName'] ?? "A player"} booked ${bookingData['stadiumName']} on ${DateFormat('MMM d').format((bookingData['startTime'] as Timestamp).toDate())} at ${DateFormat('h:mm a').format((bookingData['startTime'] as Timestamp).toDate())}.',
          type: 'info',
          createdAt: DateTime.now(),
          bookingId: ref.id,
        );
        await _firestore.collection('users').doc(bookingData['ownerId']).collection('notifications').add(ownerNotification.toFirestore());
      }

      return ref.id;
    } catch (e) {
      return null;
    }
  }

  // Update booking
  Future<bool> updateBooking(String bookingId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Delete booking
  Future<bool> deleteBooking(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== OWNER STATS ====================
  
  // Calculate owner revenue
  Future<double> calculateOwnerRevenue(String ownerId) async {
    try {
      QuerySnapshot bookings = await _firestore
          .collection('bookings')
          .where('ownerId', isEqualTo: ownerId)
          .where('paymentStatus', isEqualTo: 'paid')
          .get();

      double total = 0;
      for (var doc in bookings.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        total += (data['amount'] ?? 0).toDouble();
      }

      return total;
    } catch (e) {
      return 0;
    }
  }

  // Calculate booked hours
  Future<int> calculateBookedHours(String ownerId) async {
    try {
      QuerySnapshot bookings = await _firestore
          .collection('bookings')
          .where('ownerId', isEqualTo: ownerId)
          .get();

      int totalHours = 0;
      for (var doc in bookings.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        totalHours += (data['duration'] ?? 0) as int;
      }

      return totalHours;
    } catch (e) {
      return 0;
    }
  }
  
  // ==================== BOOKINGS ====================

  // Get bookings for a specific stadium and date
  Stream<List<Booking>> getBookingsForStadium(String stadiumId, DateTime date) {
    // Calculate start and end of the day in UTC/Local as per storage
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection('bookings')
        .where('stadiumId', isEqualTo: stadiumId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Booking.fromFirestore(doc.data(), doc.id))
            .where((b) => b.status != BookingStatus.cancelled) // Only active bookings
            .toList());
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

  // ==================== TEAMS & RANKING ====================
  // Fetch teams with optional governorate filter
  Stream<List<Team>> getTeams({String? governorate}) {
    Query query = _firestore.collection('teams');
    if (governorate != null && governorate.isNotEmpty) {
      query = query.where('governorate', isEqualTo: governorate);
    }
    
    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) {
      return Team.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
    }).toList());
  }

  Future<Team?> getTeam(String teamId) async {
    try {
      final doc = await _firestore.collection('teams').doc(teamId).get();
      if (!doc.exists) return null;
      return Team.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      debugPrint('Error getting team: $e');
      return null;
    }
  }

  Future<Team?> getTeamByCaptainPhone(String phone) async {
    try {
      final normalizedPhone = PhoneUtils.normalize(phone);
      final snapshot = await _firestore
          .collection('teams')
          .where('captainPhone', isEqualTo: normalizedPhone)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return Team.fromFirestore(snapshot.docs.first.data(), snapshot.docs.first.id);
    } catch (e) {
      debugPrint('Error getting team by captain phone: $e');
      return null;
    }
  }

  // Get Matches Stream (Placeholder for future structure)
  Stream<QuerySnapshot> getMatchesStream() {
    return _firestore.collection('matches').snapshots();
  }

  Future<String?> createTeam(Map<String, dynamic> teamData) async {
    try {
      // SECURITY HARDENING
      final sanitizedData = Map<String, dynamic>.from(teamData);
      sanitizedData.remove('points');
      sanitizedData.remove('championshipsWon');
      sanitizedData.remove('unlockedBadges');
      sanitizedData.remove('matchesPlayed');
      sanitizedData.remove('wins');
      sanitizedData.remove('draws');
      sanitizedData.remove('losses');

      DocumentReference ref = await _firestore.collection('teams').add({
        ...sanitizedData,
        'points': 0,
        'championshipsWon': 0,
        'unlockedBadges': [],
        'matchesPlayed': 0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      debugPrint('Error creating team: Masked for security');
      return null;
    }
  }

  Future<bool> updateTeam(String teamId, Map<String, dynamic> data) async {
    try {
      // SECURITY HARDENING
      final sanitizedData = Map<String, dynamic>.from(data);
      const restricted = [
        'points', 
        'championshipsWon', 
        'unlockedBadges', 
        'matchesPlayed', 
        'wins', 
        'draws', 
        'losses',
        'captainPhone',
        'uid'
      ];
      for (var f in restricted) {
        sanitizedData.remove(f);
      }

      if (sanitizedData.isEmpty) return true;

      await _firestore.collection('teams').doc(teamId).update({
        ...sanitizedData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating team: Masked for security');
      return false;
    }
  }

  Future<void> updateMatchResult(String bookingId, String homeTeamId, String awayTeamId, MatchOutcome finalOutcome) async {
    return _firestore.runTransaction((transaction) async {
      final homeRef = _firestore.collection('teams').doc(homeTeamId);
      final awayRef = _firestore.collection('teams').doc(awayTeamId);

      final homeSnap = await transaction.get(homeRef);
      final awaySnap = await transaction.get(awayRef);

      if (!homeSnap.exists || !awaySnap.exists) return;

      int homePoints = (homeSnap.data()?['points'] ?? 0).toInt();
      int awayPoints = (awaySnap.data()?['points'] ?? 0).toInt();

      final homePlayed = List<String>.from(homeSnap.data()?['playedOpponents'] ?? []);
      final awayPlayed = List<String>.from(awaySnap.data()?['playedOpponents'] ?? []);
      final homeBeaten = List<String>.from(homeSnap.data()?['beatenOpponents'] ?? []);
      final awayBeaten = List<String>.from(awaySnap.data()?['beatenOpponents'] ?? []);

      int homePointsEarned = 0;
      int awayPointsEarned = 0;

      List<String> homeBadges = List<String>.from(homeSnap.data()?['unlockedBadges'] ?? []);
      List<String> awayBadges = List<String>.from(awaySnap.data()?['unlockedBadges'] ?? []);

      bool isNewForHome = !homePlayed.contains(awayTeamId);
      bool isNewForAway = !awayPlayed.contains(homeTeamId);

      if (finalOutcome == MatchOutcome.draw) {
        homePointsEarned = 1;
        awayPointsEarned = 1;
      } else if (finalOutcome == MatchOutcome.homeWin) {
        if (homeBeaten.contains(awayTeamId)) {
          homePointsEarned = 3;
        } else {
          homePointsEarned = 5;
          if (!homeBadges.contains('Giant Killer')) homeBadges.add('Giant Killer');
          if (isNewForHome && !homeBadges.contains('New Territory')) homeBadges.add('New Territory');
          homeBeaten.add(awayTeamId); // Mark as beaten
        }
        awayPointsEarned = 0;
      } else if (finalOutcome == MatchOutcome.awayWin) {
        if (awayBeaten.contains(homeTeamId)) {
          awayPointsEarned = 3;
        } else {
          awayPointsEarned = 5;
          if (!awayBadges.contains('Giant Killer')) awayBadges.add('Giant Killer');
          if (isNewForAway && !awayBadges.contains('New Territory')) awayBadges.add('New Territory');
          awayBeaten.add(homeTeamId); // Mark as beaten
        }
        homePointsEarned = 0;
      }

      int homeStreak = (finalOutcome == MatchOutcome.homeWin) 
          ? (homeSnap.data()?['currentWinningStreak'] ?? 0) + 1 
          : 0;
      int awayStreak = (finalOutcome == MatchOutcome.awayWin) 
          ? (awaySnap.data()?['currentWinningStreak'] ?? 0) + 1 
          : 0;
          
      int homeMatchesTotal = (homeSnap.data()?['matchesPlayed'] ?? 0) + 1;
      int awayMatchesTotal = (awaySnap.data()?['matchesPlayed'] ?? 0) + 1;
      
      if (homeMatchesTotal >= 10 && !homeBadges.contains('gladiator')) homeBadges.add('gladiator');
      if (homeStreak >= 3 && !homeBadges.contains('streak_3')) homeBadges.add('streak_3');
      
      if (awayMatchesTotal >= 10 && !awayBadges.contains('gladiator')) awayBadges.add('gladiator');
      if (awayStreak >= 3 && !awayBadges.contains('streak_3')) awayBadges.add('streak_3');

      // Update Home Team
      transaction.update(homeRef, {
        'points': homePoints + homePointsEarned,
        'matchesPlayed': FieldValue.increment(1),
        'wins': FieldValue.increment(finalOutcome == MatchOutcome.homeWin ? 1 : 0),
        'draws': FieldValue.increment(finalOutcome == MatchOutcome.draw ? 1 : 0),
        'losses': FieldValue.increment(finalOutcome == MatchOutcome.awayWin ? 1 : 0),
        'trend': homePointsEarned > 0 ? 'up' : 'stable',
        'currentWinningStreak': homeStreak,
        'unlockedBadges': homeBadges,
        'beatenOpponents': homeBeaten,
        if (isNewForHome) 'playedOpponents': FieldValue.arrayUnion([awayTeamId]),
      });

      // Update Away Team
      transaction.update(awayRef, {
        'points': awayPoints + awayPointsEarned,
        'matchesPlayed': FieldValue.increment(1),
        'wins': FieldValue.increment(finalOutcome == MatchOutcome.awayWin ? 1 : 0),
        'draws': FieldValue.increment(finalOutcome == MatchOutcome.draw ? 1 : 0),
        'losses': FieldValue.increment(finalOutcome == MatchOutcome.homeWin ? 1 : 0),
        'trend': awayPointsEarned > 0 ? 'up' : 'stable',
        'currentWinningStreak': awayStreak,
        'unlockedBadges': awayBadges,
        'beatenOpponents': awayBeaten,
        if (isNewForAway) 'playedOpponents': FieldValue.arrayUnion([homeTeamId]),
      });
      
      // Update Booking status
      transaction.update(_firestore.collection('bookings').doc(bookingId), {
        'status': BookingStatus.completed.name,
        'finalOutcome': finalOutcome.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<List<Team>> searchOpponentTeams(String query) async {
    try {
      if (query.isEmpty) return [];

      final isPhone = RegExp(r'^\+?[0-9]{3,}$').hasMatch(query);
      Query queryRef = _firestore.collection('teams');

      if (isPhone) {
        final normalized = PhoneUtils.normalize(query);
        queryRef = queryRef.where('captainPhone', isEqualTo: normalized);
      } else {
        // Simple case-insensitive start-search (normalized for case in DB ideally, but VSP uses prefix match)
        queryRef = queryRef
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(10);
      }

      final snapshot = await queryRef.get();
      return snapshot.docs
          .map((doc) => Team.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error searching teams: $e');
      return [];
    }
  }

  /// Previous Opponents: Find teams played against in COMPLETED matches
  Future<List<Team>> getPreviousOpponents(String myTeamId) async {
    try {
      final snapshot = await _firestore.collection('bookings')
          .where('playerTeamId', isEqualTo: myTeamId)
          .where('bookingType', isEqualTo: 'challenge')
          .where('status', isEqualTo: 'completed')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final Set<String> opponentIds = {};
      for (var doc in snapshot.docs) {
        final oppId = doc.data()['opponentTeamId'];
        if (oppId != null) opponentIds.add(oppId);
      }

      if (opponentIds.isEmpty) return [];

      // Fetch full team models
      final teams = <Team>[];
      for (var id in opponentIds) {
        final tDoc = await _firestore.collection('teams').doc(id).get();
        if (tDoc.exists) {
           teams.add(Team.fromFirestore(tDoc.data()!, tDoc.id));
        }
      }
      return teams;
    } catch (e) {
      debugPrint('Error fetching history: $e');
      return [];
    }
  }

  Stream<List<AppNotification>> getUserNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> sendNotification(String userId, AppNotification notification) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add(notification.toFirestore());
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  Future<void> markNotificationAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();
      
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<Map<String, int>> getHeadToHeadStats(String teamAId, String teamBId) async {
    try {
      final q1 = await _firestore.collection('bookings')
          .where('status', isEqualTo: BookingStatus.completed.name)
          .where('bookingType', isEqualTo: BookingType.challenge.name)
          .where('playerTeamId', isEqualTo: teamAId)
          .where('opponentTeamId', isEqualTo: teamBId)
          .get();

      final q2 = await _firestore.collection('bookings')
          .where('status', isEqualTo: BookingStatus.completed.name)
          .where('bookingType', isEqualTo: BookingType.challenge.name)
          .where('playerTeamId', isEqualTo: teamBId)
          .where('opponentTeamId', isEqualTo: teamAId)
          .get();

      int teamAWins = 0;
      int teamBWins = 0;
      int draws = 0;

      for (var doc in q1.docs) {
        final outcome = doc.data()['finalOutcome'];
        if (outcome == MatchOutcome.homeWin.name) {
          teamAWins++;
        } else if (outcome == MatchOutcome.awayWin.name) {
          teamBWins++;
        } else {
          draws++;
        }
      }

      for (var doc in q2.docs) {
        final outcome = doc.data()['finalOutcome'];
        if (outcome == MatchOutcome.homeWin.name) {
          teamBWins++;
        } else if (outcome == MatchOutcome.awayWin.name) {
          teamAWins++;
        } else {
          draws++;
        }
      }

      return {
        'teamAWins': teamAWins,
        'teamBWins': teamBWins,
        'draws': draws,
        'totalMatches': teamAWins + teamBWins + draws,
      };
    } catch (e) {
      debugPrint('Error fetching H2H stats: $e');
      return {'teamAWins': 0, 'teamBWins': 0, 'draws': 0, 'totalMatches': 0};
    }
  }

  Future<bool> addMemberToTeam(String teamId, String userId, String profileImageUrl) async {
    try {
      await _firestore.collection('teams').doc(teamId).update({
        'memberUids': FieldValue.arrayUnion([userId]),
        'playerImages': FieldValue.arrayUnion([profileImageUrl]),
        'playersCount': FieldValue.increment(1),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding member to team: $e');
      return false;
    }
  }

  Future<bool> removeMemberFromTeam(String teamId, String userId, String profileImageUrl) async {
    try {
      await _firestore.collection('teams').doc(teamId).update({
        'memberUids': FieldValue.arrayRemove([userId]),
        'playerImages': FieldValue.arrayRemove([profileImageUrl]),
        'playersCount': FieldValue.increment(-1),
      });
      return true;
    } catch (e) {
      debugPrint('Error removing member from team: $e');
      return false;
    }
  }

  // ==================== PUBLIC MATCHES ====================

  Stream<List<Booking>> getPublicMatches() {
    final now = DateTime.now();
    
    // Only query by status to avoid Composite Index requirements
    return _firestore
        .collection('bookings')
        .where('status', isEqualTo: BookingStatus.confirmed.name)
        .snapshots()
        .map<List<Booking>>((snapshot) {
          try {
            // 1. Map to Booking objects
            var matches = snapshot.docs
                .map((doc) => Booking.fromFirestore(doc.data(), doc.id))
                .toList();

            // 2. Filter locally in Dart
            matches = matches.where((b) {
              final isPublic = b.isPrivate == false; 
              final isFuture = b.startTime.isAfter(now);
              // Capacity logic: maxPlayers is per-team, so field capacity is x2
              final fieldCapacity = b.maxPlayers > 0 ? b.maxPlayers * 2 : 10;
              final hasSpace = b.currentPlayers < fieldCapacity;
              final isRightType = b.bookingType == BookingType.team || b.bookingType == BookingType.personal;
              return isPublic && isFuture && hasSpace && isRightType;
            }).toList();

            // 3. Sort locally by createdAt descending
            matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            debugPrint('✅ Found ${matches.length} active public matches');
            return matches;
          } catch (e) {
            debugPrint('❌ Error parsing public matches: $e');
            return []; 
          }
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

      // 1. Transaction Complete
      
      // 2. Determine if match is now full
      final finalDoc = await docRef.get();
      final finalData = finalDoc.data() as Map<String, dynamic>;
      final finalCurrent = finalData['currentPlayers'] ?? 0;
      final finalMax = finalData['maxPlayers'] ?? 0;
      final totalCapacity = finalMax > 0 ? finalMax * 2 : 10;
      final participantIds = List<String>.from(finalData['joinedUserIds'] ?? []);

      // 3. Get joining user name for notification
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          joiningUserName = userDoc.data()?['name'] ?? 'A player';
        }
      } catch (_) {}

      // 4. Send Notifications
      if (hostId.isNotEmpty && hostId != userId) {
        await NotificationHandler.notifyPlayerJoinedMatch(
          hostId: hostId,
          playerName: joiningUserName,
          stadiumName: stadiumName,
          bookingId: bookingId,
        );
      }

      // Check if full
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

      // Get user name for notification
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
            leavingUserName = userDoc.data()?['name'] ?? 'A player';
        }
      } catch (_) {}

      if (hostId.isNotEmpty && hostId != userId) {
        await sendNotification(
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
      debugPrint('Error leaving public match: $e');
      return false;
    }
  }

  /// Host-only: remove a specific participant from a public match
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

      // Notify the removed player
      await sendNotification(
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
      debugPrint('Error removing participant from public match: $e');
      return false;
    }
  }

  /// Host-only: Update the number of initial players the host brings
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
      debugPrint('Error updating host spots: $e');
      return false;
    }
  }

  // BETA READY: Unified team fetch for Captains AND Members
  Future<Team?> getUserTeam(String userId) async {
    try {
      final query = await _firestore.collection('teams')
          .where('memberUids', arrayContains: userId)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return Team.fromFirestore(query.docs.first.data(), query.docs.first.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user team: $e');
      return null;
    }
  }

  // BETA READY: Interactive notification action logic
  Future<void> respondToChallenge(String userId, String notificationId, String bookingId, bool accept) async {
    try {
      final batch = _firestore.batch();
      
      // 1. Mark notification as read
      batch.update(_firestore.collection('users').doc(userId).collection('notifications').doc(notificationId), {
        'isRead': true,
      });

      // 2. Update booking status
      batch.update(_firestore.collection('bookings').doc(bookingId), {
        'status': accept ? 'confirmed' : 'cancelled',
      });

      await batch.commit();
    } catch (e) {
      debugPrint('Error responding to challenge: $e');
    }
  }


  // BETA READY: Delete team logic
  Future<bool> deleteTeam(String teamId) async {
    try {
      await _firestore.collection('teams').doc(teamId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting team: $e');
      return false;
    }
  }


  // ==================== VSP 1v1 LEAGUE ====================
  
  Stream<List<VSP1v1Player>> get1v1Standings() {
    return _firestore
        .collection('vsp_1VS1_players')
        .orderBy('totalPoints', descending: true) // Sort by points automatically
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            // No players in league yet
            return [];
          }
          
          List<VSP1v1Player> players = [];
          for (int i = 0; i < snapshot.docs.length; i++) {
            // Force recalculate rank based on sort order just to be safe
            var data = snapshot.docs[i].data();
            data['rank'] = i + 1; 
            players.add(VSP1v1Player.fromFirestore(data, snapshot.docs[i].id));
          }
          return players;
        });
  }


  // ==================== PAGINATION & PERFORMANCE ====================


  /// Fetch public matches in batches of 10
  Future<Map<String, dynamic>> getPublicMatchesPaginated({
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection('bookings')
          .where('status', isEqualTo: BookingStatus.confirmed.name)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final now = DateTime.now();
      
      final items = snapshot.docs
          .map((doc) => Booking.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .where((b) {
            // Must be Public (Find Players)
            final isPublic = b.isPrivate == false; 
            
            // Must be in the Future
            final isFuture = b.startTime.isAfter(now);
            
            // Must have space
            final max = b.maxPlayers > 0 ? b.maxPlayers : 10;
            final hasSpace = b.currentPlayers < max;
            
            // Focus on TEAM type for "Find Players" feed
            // We allow team and personal for now, but team is the primary "Joinable" type from confirmation flow
            final isRightType = b.bookingType == BookingType.team || b.bookingType == BookingType.personal;
            
            final isValid = isPublic && isFuture && hasSpace && isRightType;
            
            if (!isValid) {
              debugPrint('Filtered out match: ${b.id} (Public: $isPublic, Future: $isFuture, Space: $hasSpace, RightType: $isRightType)');
            }
            
            return isValid;
          }).toList();
      
      return {
        'items': items,
        'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      };
    } catch (e) {
      debugPrint('Error fetching paginated matches: $e');
      return {'items': [], 'lastDoc': null};
    }
  }

  // ==================== GLOBAL UNIFIED SEARCH ====================

  /// Search across Stadiums, Teams, and Championships simultaneously
  Future<Map<String, List<dynamic>>> globalUnifiedSearch(String query) async {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return {'stadiums': [], 'teams': [], 'championships': []};

    try {
      // 1. Search Stadiums
      final stadiumSnap = await _firestore.collection('stadiums')
          .where('name_lowercase', isGreaterThanOrEqualTo: term)
          .where('name_lowercase', isLessThanOrEqualTo: '$term\uf8ff')
          .limit(5)
          .get();
      
      final stadiums = stadiumSnap.docs.map((d) => Stadium.fromFirestore(d.data(), d.id)).toList();

      // 2. Search Teams
      final teamSnap = await _firestore.collection('teams')
          .where('name_lowercase', isGreaterThanOrEqualTo: term)
          .where('name_lowercase', isLessThanOrEqualTo: '$term\uf8ff')
          .limit(5)
          .get();
      
      final teams = teamSnap.docs.map((d) => Team.fromFirestore(d.data(), d.id)).toList();

      // 3. Search Championships
      final champSnap = await _firestore.collection('championships')
          .where('name_lowercase', isGreaterThanOrEqualTo: term)
          .where('name_lowercase', isLessThanOrEqualTo: '$term\uf8ff')
          .limit(5)
          .get();
      
      final championships = champSnap.docs.map((d) => Championship.fromFirestore(d.data(), d.id)).toList();

      return {
        'stadiums': stadiums,
        'teams': teams,
        'championships': championships,
      };
    } catch (e) {
      debugPrint('Error in global search: $e');
      return {'stadiums': [], 'teams': [], 'championships': []};
    }
  }

  // ==================== COMMUNITY SAFETY & MODERATION ====================

  /// Report a user, team, or match for misconduct
  Future<bool> reportEntity({
    required String reporterId,
    required String targetId,
    required String targetType, // 'user', 'team', 'match'
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
        'status': 'pending', // pending, reviewed, resolved
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      VSPLogger.e('Error reporting entity', e);
      return false;
    }
  }

  /// Get reports for admin dashboard
  Stream<List<Map<String, dynamic>>> getReportsStream() {
    return _firestore.collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  /// Admin action: Warn or Suspend user
  Future<void> updateUserModerationStatus(String userId, {required bool isSuspended, String? warningMessage}) async {
    try {
      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(userId);
      
      batch.update(userRef, {
        'isSuspended': isSuspended,
        if (warningMessage != null) 'lastWarning': warningMessage,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // If warning, also send a notification
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
      debugPrint('Error updating user moderation status: $e');
    }
  }


  // ── DEBT MANAGEMENT ────────────────────────────────
  
  /// Get all unpaid bookings for a user (isPaid == false)
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

  /// Update user profile fields in Firestore (e.g., isBlocked)
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      VSPLogger.e('Error updating user profile $userId', e);
    }
  }

  /// Delete a notification (for swipe-to-dismiss)
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      VSPLogger.e('Error deleting notification $notificationId', e);
    }
  }

  /// Get unread notification count for badge
  Stream<int> getUnreadNotificationCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}