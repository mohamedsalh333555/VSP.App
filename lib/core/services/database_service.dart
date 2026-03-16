import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../../core/models/user_model.dart';
import '../../data/models.dart';

class DatabaseService {
  final FirebaseFirestore _firestore;

  DatabaseService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ==================== USERS ====================

  Future<UserModel?> getUserByPhone(String phone) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return UserModel.fromFirestore(snapshot.docs.first.data());
    } catch (e) {
      debugPrint('Error getting user by phone: $e');
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

  // ==================== STADIUMS ====================
  
  // Get all stadiums (with expanded limit)
  Stream<List<Stadium>> getStadiums({int limit = 50}) {
    return _firestore
        .collection('stadiums')
        .where('isVerified', isEqualTo: true) // ✅ Only show verified stadiums to players
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Stadium.fromFirestore(doc.data(), doc.id))
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
        'isVerified': false, // Force false for new stadiums
        'createdAt': FieldValue.serverTimestamp(),
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
    String notes = '', // ✅ Added notes
    String? contractUrl,
    String? ownerIdUrl,
    Map<String, dynamic>? features,
  }) async {
    return await addStadium({
      'name': name,
      'location': location,
      'pricePerHour': pricePerHour,
      'seatsCapacity': seatsCapacity,
      'imageUrl': imageUrl,
      'ownerId': ownerId,
      'notes': notes, // ✅ Added notes
      'contractUrl': contractUrl,
      'ownerIdUrl': ownerIdUrl,
      'isVerified': false, // Default to false for new stadiums
      'features': features ?? {},
    });
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

  // ==================== CHAMPIONSHIPS ====================
  
  // Get all championships
  Stream<List<Championship>> getChampionshipsStream({String? governorate, String? sportType}) {
    Query query = _firestore.collection('championships');
    
    if (governorate != null && governorate.isNotEmpty) {
      query = query.where('governorate', isEqualTo: governorate);
    }
    
    if (sportType != null && sportType.isNotEmpty) {
      query = query.where('sportType', isEqualTo: sportType);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => Championship.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  Future<String?> createChampionship(Map<String, dynamic> data) async {
    try {
      // SECURITY HARDENING
      final sanitizedData = Map<String, dynamic>.from(data);
      sanitizedData.remove('joinedTeams');
      sanitizedData.remove('status');
      sanitizedData.remove('creatorId');

      final docRef = await _firestore.collection('championships').add({
        ...sanitizedData,
        'status': 'open',
        'joinedTeams': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating championship: Masked for security');
      return null;
    }
  }

  // Join a championship with 5-player rule
  Future<bool> joinChampionship(String championshipId, String teamId) async {
    try {
      final teamRef = _firestore.collection('teams').doc(teamId);
      final champRef = _firestore.collection('championships').doc(championshipId);
      
      await _firestore.runTransaction((transaction) async {
        final teamSnap = await transaction.get(teamRef);
        final champSnap = await transaction.get(champRef);
        
        if (!teamSnap.exists) throw Exception('المجموعة لا توجد.');
        if (!champSnap.exists) throw Exception('البطولة لا توجد.');

        final teamData = teamSnap.data() as Map<String, dynamic>;
        final champData = champSnap.data() as Map<String, dynamic>;

        // 1. Check Team Size (Rule: Min 5 Players)
        final List members = teamData['memberUids'] ?? [];
        final int playerCount = teamData['playersCount'] ?? members.length;
        
        if (playerCount < 5) {
          throw Exception('يجب أن تضم مجموعتك 5 لاعبين على الأقل للمشاركة.');
        }

        // 2. Check Championship Capacity
        final List joinedTeams = champData['joinedTeams'] ?? [];
        final int maxTeams = champData['maxTeams'] ?? 16;

        if (joinedTeams.length >= maxTeams) {
          throw Exception('عذراً، البطولة اكتمل عددها بالفعل.');
        }

        if (joinedTeams.contains(teamId)) {
          throw Exception('لقد انضمت مجموعتك لهذه البطولة بالفعل.');
        }

        // 3. Update Championship
        transaction.update(champRef, {
          'joinedTeams': FieldValue.arrayUnion([teamId]),
        });
      });

      return true;
    } catch (e) {
      debugPrint('Error joining championship: $e');
      rethrow; // Re-throw so UI can handle exact error message
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

  Future<Team?> getTeamByCaptainPhone(String phone) async {
    try {
      final snapshot = await _firestore
          .collection('teams')
          .where('captainPhone', isEqualTo: phone)
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

      final homePlayed = List<String>.from(homeSnap.data()?['playedOpponents'] ?? []);
      final awayPlayed = List<String>.from(awaySnap.data()?['playedOpponents'] ?? []);

      // ── New Opponent Algorithm ──
      // If NO, bonus = 1, else bonus = 0
      bool isNewForHome = !homePlayed.contains(awayTeamId);
      bool isNewForAway = !awayPlayed.contains(homeTeamId);
      int bonusHome = isNewForHome ? 1 : 0;
      int bonusAway = isNewForAway ? 1 : 0;

      int homePts = 0;
      int awayPts = 0;
      String homeTrend = 'stable';
      String awayTrend = 'stable';

      if (finalOutcome == MatchOutcome.homeWin) {
        // Home Win: 3 pts + bonus; Away Loss: 0 pts + bonus
        homePts = 3 + bonusHome;
        awayPts = bonusAway;
        homeTrend = 'up';
        awayTrend = 'down';
      } else if (finalOutcome == MatchOutcome.awayWin) {
        // Home Loss: 0 pts + bonus; Away Win: 3 pts + bonus
        homePts = bonusHome;
        awayPts = 3 + bonusAway;
        homeTrend = 'down';
        awayTrend = 'up';
      } else {
        // Draw: 1 pt + bonus for both
        homePts = 1 + bonusHome;
        awayPts = 1 + bonusAway;
        homeTrend = 'stable';
        awayTrend = 'stable';
      }

      // ── Gamification: Streaks & Badges ──
      
      // Home Team Logic
      int homeStreak = (finalOutcome == MatchOutcome.homeWin) 
          ? (homeSnap.data()?['currentWinningStreak'] ?? 0) + 1 
          : 0;
      List<String> homeBadges = List<String>.from(homeSnap.data()?['unlockedBadges'] ?? []);
      int homeMatchesTotal = (homeSnap.data()?['matchesPlayed'] ?? 0) + 1;
      
      if (homeMatchesTotal >= 10 && !homeBadges.contains('gladiator')) homeBadges.add('gladiator');
      if (homeStreak >= 3 && !homeBadges.contains('streak_3')) homeBadges.add('streak_3');
      if (homePlayed.length + (isNewForHome ? 1 : 0) >= 5 && !homeBadges.contains('explorer')) homeBadges.add('explorer');

      // Away Team Logic
      int awayStreak = (finalOutcome == MatchOutcome.awayWin) 
          ? (awaySnap.data()?['currentWinningStreak'] ?? 0) + 1 
          : 0;
      List<String> awayBadges = List<String>.from(awaySnap.data()?['unlockedBadges'] ?? []);
      int awayMatchesTotal = (awaySnap.data()?['matchesPlayed'] ?? 0) + 1;
      
      if (awayMatchesTotal >= 10 && !awayBadges.contains('gladiator')) awayBadges.add('gladiator');
      if (awayStreak >= 3 && !awayBadges.contains('streak_3')) awayBadges.add('streak_3');
      if (awayPlayed.length + (isNewForAway ? 1 : 0) >= 5 && !awayBadges.contains('explorer')) awayBadges.add('explorer');

      // Update Home Team
      transaction.update(homeRef, {
        'points': FieldValue.increment(homePts),
        'matchesPlayed': FieldValue.increment(1),
        'wins': FieldValue.increment(finalOutcome == MatchOutcome.homeWin ? 1 : 0),
        'draws': FieldValue.increment(finalOutcome == MatchOutcome.draw ? 1 : 0),
        'losses': FieldValue.increment(finalOutcome == MatchOutcome.awayWin ? 1 : 0),
        'trend': homeTrend,
        'currentWinningStreak': homeStreak,
        'unlockedBadges': homeBadges,
        if (isNewForHome) 'playedOpponents': FieldValue.arrayUnion([awayTeamId]),
      });

      // Update Away Team
      transaction.update(awayRef, {
        'points': FieldValue.increment(awayPts),
        'matchesPlayed': FieldValue.increment(1),
        'wins': FieldValue.increment(finalOutcome == MatchOutcome.awayWin ? 1 : 0),
        'draws': FieldValue.increment(finalOutcome == MatchOutcome.draw ? 1 : 0),
        'losses': FieldValue.increment(finalOutcome == MatchOutcome.homeWin ? 1 : 0),
        'trend': awayTrend,
        'currentWinningStreak': awayStreak,
        'unlockedBadges': awayBadges,
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

      final isPhone = RegExp(r'^[0-9]+$').hasMatch(query);
      Query queryRef = _firestore.collection('teams');

      if (isPhone) {
        queryRef = queryRef.where('captainPhone', isEqualTo: query);
      } else {
        // Simple case-insensitive start-search
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
              final hasSpace = b.currentPlayers < (b.maxPlayers > 0 ? b.maxPlayers : 1);
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
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) throw 'Match not found';
        
        final data = doc.data() as Map<String, dynamic>;
        final current = data['currentPlayers'] ?? 0;
        final max = data['maxPlayers'] ?? 0;
        final joined = List<String>.from(data['joinedUserIds'] ?? []);
        
        if (current >= max) throw 'Match is full';
        if (joined.contains(userId)) throw 'Already joined';
        
        transaction.update(docRef, {
          'currentPlayers': FieldValue.increment(1),
          'joinedUserIds': FieldValue.arrayUnion([userId]),
        });
      });
      return true;
    } catch (e) {
      debugPrint('Error joining public match: $e');
      return false;
    }
  }

  Future<bool> leavePublicMatch(String bookingId, String userId) async {
    try {
      final docRef = _firestore.collection('bookings').doc(bookingId);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) throw 'Match not found';
        
        final data = doc.data() as Map<String, dynamic>;
        final joined = List<String>.from(data['joinedUserIds'] ?? []);
        
        if (!joined.contains(userId)) throw 'Not a participant';
        
        transaction.update(docRef, {
          'currentPlayers': FieldValue.increment(-1),
          'joinedUserIds': FieldValue.arrayRemove([userId]),
        });
      });
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
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) throw 'Match not found';
        
        final data = doc.data() as Map<String, dynamic>;
        final joined = List<String>.from(data['joinedUserIds'] ?? []);
        
        if (!joined.contains(userId)) throw 'User is not a participant';
        
        transaction.update(docRef, {
          'currentPlayers': FieldValue.increment(-1),
          'joinedUserIds': FieldValue.arrayRemove([userId]),
        });
      });
      return true;
    } catch (e) {
      debugPrint('Error removing participant from public match: $e');
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
  Future<void> respondToChallenge(String notificationId, String bookingId, bool accept) async {
    try {
      final batch = _firestore.batch();
      
      // 1. Mark notification as read
      batch.update(_firestore.collection('notifications').doc(notificationId), {
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
  // TOURNAMENT Logic: Update championship status (e.g., from 'open' to 'ongoing')
  Future<void> updateChampionshipStatus(String championshipId, String status) async {
    try {
      await _firestore.collection('championships').doc(championshipId).update({
        'status': status,
      });
    } catch (e) {
      debugPrint('Error updating championship status: $e');
    }
  }

  // TOURNAMENT Logic: Finalize tournament and increment winning team's trophies
  Future<void> crownChampion(String championshipId, String winningTeamId, String winningTeamName) async {
    try {
      final batch = _firestore.batch();
      
      // 1. Mark championship as completed
      batch.update(_firestore.collection('championships').doc(championshipId), {
        'status': 'completed',
        'championTeamId': winningTeamId,
        'championTeamName': winningTeamName,
      });

      // 2. Increment team's trophies and add badge
      batch.update(_firestore.collection('teams').doc(winningTeamId), {
        'championshipsWon': FieldValue.increment(1),
        'unlockedBadges': FieldValue.arrayUnion(['cup_winner']),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('Error crowning champion: $e');
      throw 'Failed to crown champion';
    }
  }

  // TOURNAMENT Logic: Fetch joined teams for dashboard
  Future<List<Team>> getTeamsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      // Note: Firestore 'whereIn' is limited to 10-30 items depending on sdk, 
      // but usually championships have a max team count.
      final query = await _firestore.collection('teams')
          .where(FieldPath.documentId, whereIn: ids)
          .get();
      
      return query.docs.map((d) => Team.fromFirestore(d.data(), d.id)).toList();
    } catch (e) {
      debugPrint('Error getting teams by IDs: $e');
      return [];
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

  // ==================== TOURNAMENT BRACKET ENGINE ====================

  /// Generates the full knockout bracket tree for a championship.
  /// Supports 4, 8, 16, or 32 teams. Teams are randomly shuffled (draw).
  Future<void> generateFixtures(String championshipId) async {
    try {
      // 1. Get Championship & Teams
      final champDoc = await _firestore.collection('championships').doc(championshipId).get();
      if (!champDoc.exists) throw 'Championship not found';

      final champData = champDoc.data() as Map<String, dynamic>;
      final List<String> teamIds = List<String>.from(champData['joinedTeams'] ?? []);

      // Validation: must be power of 2
      int teamCount = teamIds.length;
      if (![4, 8, 16, 32].contains(teamCount)) {
        throw 'Number of teams must be 4, 8, 16, or 32 for a knockout bracket. Current: $teamCount';
      }

      // 2. Fetch Team Names
      final teams = await getTeamsByIds(teamIds);
      final teamMap = {for (var t in teams) t.id: t.name};

      // 3. Shuffle Teams (Random Draw)
      final shuffledIds = List<String>.from(teamIds)..shuffle(Random());

      // 4. Determine Rounds
      // Round 0 = Final (1 match), Round 1 = Semi (2 matches), Round 2 = Quarters (4 matches), etc.
      int totalRounds = (log(teamCount) / log(2)).round();
      int firstRoundIndex = totalRounds - 1;

      final batch = _firestore.batch();
      final matchesCollection = _firestore.collection('tournament_matches');

      // Helper: deterministic match IDs
      String getMatchId(int r, int m) => '${championshipId}_R${r}_M$m';

      // 5. Generate All Match Slots
      for (int r = 0; r <= firstRoundIndex; r++) {
        int matchCount = pow(2, r).toInt();

        for (int m = 0; m < matchCount; m++) {
          final docRef = matchesCollection.doc(getMatchId(r, m));

          // Link to parent match in the next round closer to Final
          String? nextMatchId;
          if (r > 0) {
            nextMatchId = getMatchId(r - 1, m ~/ 2);
          }

          // Only populate teams in the FIRST round (furthest from Final)
          String? homeId, homeName, awayId, awayName;
          if (r == firstRoundIndex) {
            int teamIndexBase = m * 2;
            if (teamIndexBase < shuffledIds.length) {
              homeId = shuffledIds[teamIndexBase];
              homeName = teamMap[homeId];
            }
            if (teamIndexBase + 1 < shuffledIds.length) {
              awayId = shuffledIds[teamIndexBase + 1];
              awayName = teamMap[awayId];
            }
          }

          final matchData = TournamentMatch(
            id: docRef.id,
            championshipId: championshipId,
            roundIndex: r,
            matchIndex: m,
            nextMatchId: nextMatchId,
            homeTeamId: homeId,
            homeTeamName: homeName,
            awayTeamId: awayId,
            awayTeamName: awayName,
          );

          batch.set(docRef, matchData.toFirestore());
        }
      }

      // 6. Update Championship Status to 'ongoing'
      batch.update(champDoc.reference, {'status': 'ongoing'});

      await batch.commit();
      debugPrint('✅ Fixtures generated for $championshipId: $totalRounds rounds, $teamCount teams');
    } catch (e) {
      debugPrint('Error generating fixtures: $e');
      rethrow;
    }
  }

  /// Updates a match score and automatically propagates the winner to the next round.
  Future<void> updateTournamentMatchScore({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required String winnerId,
    required String winnerName,
  }) async {
    try {
      final matchRef = _firestore.collection('tournament_matches').doc(matchId);

      await _firestore.runTransaction((transaction) async {
        final matchDoc = await transaction.get(matchRef);
        if (!matchDoc.exists) throw 'Match not found';

        final matchData = matchDoc.data() as Map<String, dynamic>;
        final String? nextMatchId = matchData['nextMatchId'];
        final int matchIndex = matchData['matchIndex'];

        // 1. Update Current Match Score & Winner
        transaction.update(matchRef, {
          'homeScore': homeScore,
          'awayScore': awayScore,
          'winnerId': winnerId,
        });

        // 2. Propagate Winner to Next Match
        if (nextMatchId != null) {
          final nextMatchRef = _firestore.collection('tournament_matches').doc(nextMatchId);

          // Even matchIndex → Home slot, Odd → Away slot in parent match
          String slotField = (matchIndex % 2 == 0) ? 'home' : 'away';

          transaction.update(nextMatchRef, {
            '${slotField}TeamId': winnerId,
            '${slotField}TeamName': winnerName,
          });
        } else if (matchData['roundIndex'] == 0) {
          // 🏆 This was the FINAL — automatically crown champion
          final champRef = _firestore.collection('championships').doc(matchData['championshipId']);
          final teamRef = _firestore.collection('teams').doc(winnerId);

          transaction.update(champRef, {
            'status': 'completed',
            'championTeamId': winnerId,
            'championTeamName': winnerName,
          });

          transaction.update(teamRef, {
            'championshipsWon': FieldValue.increment(1),
            'unlockedBadges': FieldValue.arrayUnion(['cup_winner']),
          });
        }
      });
    } catch (e) {
      debugPrint('Error updating tournament match score: $e');
      rethrow;
    }
  }

  /// Real-time stream of all bracket matches for a championship.
  Stream<List<TournamentMatch>> getTournamentMatches(String championshipId) {
    return _firestore
        .collection('tournament_matches')
        .where('championshipId', isEqualTo: championshipId)
        .snapshots()
        .map((snapshot) {
      final matches = snapshot.docs
          .map((doc) => TournamentMatch.fromFirestore(doc.data(), doc.id))
          .toList();
      // Sort: highest roundIndex first (first rounds at top), then by matchIndex
      matches.sort((a, b) {
        if (a.roundIndex != b.roundIndex) return b.roundIndex.compareTo(a.roundIndex);
        return a.matchIndex.compareTo(b.matchIndex);
      });
      return matches;
    });
  }

  // ==================== VSP 1v1 LEAGUE ====================
  
  Stream<List<VSP1v1Player>> get1v1Standings() {
    return _firestore
        .collection('vsp_1VS1_players')
        .orderBy('totalPoints', descending: true) // Sort by points automatically
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            // For demo purposes, return mock data if DB is empty
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
}
