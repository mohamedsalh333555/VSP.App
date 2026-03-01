import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/user_model.dart';
import '../../data/models.dart';

class DatabaseService {
  // Active Instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      DocumentReference ref = await _firestore.collection('stadiums').add({
        ...stadiumData,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      debugPrint('Error adding stadium: $e');
      return null;
    }
  }

  // Update stadium
  Future<bool> updateStadium(String stadiumId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('stadiums').doc(stadiumId).update(data);
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
      final docRef = await _firestore.collection('championships').add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating championship: $e');
      return null;
    }
  }

  // Join a championship
  Future<bool> joinChampionship(String championshipId, String teamId) async {
    try {
      DocumentReference champRef = _firestore.collection('championships').doc(championshipId);
      
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot champSnapshot = await transaction.get(champRef);
        
        if (!champSnapshot.exists) {
          throw Exception('Championship does not exist');
        }

        Map<String, dynamic> champData = champSnapshot.data() as Map<String, dynamic>;
        List<dynamic> joinedTeams = champData['joinedTeams'] ?? [];
        int maxTeams = champData['maxTeams'] ?? 0;

        if (joinedTeams.length >= maxTeams) {
          throw Exception('Championship is full');
        }

        if (joinedTeams.contains(teamId)) {
          throw Exception('Team already joined');
        }

        transaction.update(champRef, {
          'joinedTeams': FieldValue.arrayUnion([teamId]),
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

  // Create booking
  Future<String?> createBooking(Map<String, dynamic> bookingData) async {
    try {
      DocumentReference ref = await _firestore.collection('bookings').add({
        ...bookingData,
        'createdAt': FieldValue.serverTimestamp(),
      });
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
            .map((doc) => Booking.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
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
      return Team.fromFirestore(snapshot.docs.first.data() as Map<String, dynamic>, snapshot.docs.first.id);
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
      DocumentReference ref = await _firestore.collection('teams').add({
        ...teamData,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      debugPrint('Error creating team: $e');
      return null;
    }
  }

  Future<bool> updateTeam(String teamId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('teams').doc(teamId).update(data);
      return true;
    } catch (e) {
      debugPrint('Error updating team: $e');
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
            .where('name', isLessThanOrEqualTo: query + '\uf8ff')
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
        if (outcome == MatchOutcome.homeWin.name) teamAWins++;
        else if (outcome == MatchOutcome.awayWin.name) teamBWins++;
        else draws++;
      }

      for (var doc in q2.docs) {
        final outcome = doc.data()['finalOutcome'];
        if (outcome == MatchOutcome.homeWin.name) teamBWins++;
        else if (outcome == MatchOutcome.awayWin.name) teamAWins++;
        else draws++;
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
    return _firestore
        .collection('bookings')
        .where('isPrivate', isEqualTo: false)
        .where('status', isEqualTo: BookingStatus.confirmed.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Booking.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .where((b) => b.startTime.isAfter(now) && b.currentPlayers < b.maxPlayers)
            .toList());
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
}


