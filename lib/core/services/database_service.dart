import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models.dart';

class DatabaseService {
  // Active Instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== STADIUMS ====================
  
  // Get all stadiums (with expanded limit)
  Stream<List<Stadium>> getStadiums({int limit = 50}) {
    return _firestore
        .collection('stadiums')
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
        // ownerId should already be in stadiumData, but safety fallbacks can be handled in calling method
      });
      return ref.id;
    } catch (e) {
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
  Stream<List<Map<String, dynamic>>> getChampionships() {
    return _firestore
        .collection('championships')
        .orderBy('startDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
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
  
  // ==================== TEAMS & RANKING ====================
  // Helper to fetch teams (used in PlayerHomeScreen for now until match structure is set)
  Stream<List<Team>> getTeams() {
    return _firestore
        .collection('teams')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
             final data = doc.data();
             // Map Firestore data to Team model
             return Team(
               id: doc.id,
               name: data['name'] ?? '',
               stadium: 'TBD', // This info isn't in seeded team data, defaulting
               date: 'Upcoming', 
               captainName: 'Captain', // Mock if not joined
               captainImageUrl: data['logoUrl'] ?? '',
               playerImages: List<String>.from(data['members'] ?? []),
               maxPlayers: 11,
               currentPlayers: data['playersCount'] ?? 11,
               pricePerPerson: 50.0,
             );
        }).toList());
  }

  // Get Matches Stream (Placeholder for future structure)
  Stream<QuerySnapshot> getMatchesStream() {
    return _firestore.collection('matches').snapshots();
  }

  // Confirm Match Result & Update Ranking
  Future<void> updateMatchResult(String matchId, String winningTeamId) async {
    final batch = _firestore.batch();
    
    // 1. Update Match Status
    // DocumentReference matchRef = _firestore.collection('matches').doc(matchId);
    // batch.update(matchRef, {'status': 'completed', 'winner': winningTeamId});
    // Note: Since we don't have matches seeded yet, we will focus on updating the Team Points directly for the demo.
    
    // 2. Increment Team Points
    DocumentReference teamRef = _firestore.collection('teams').doc(winningTeamId);
    batch.update(teamRef, {
      'points': FieldValue.increment(3),
      'trend': 'up'
    });
    
    // 3. Create Transaction Record (Financial & Logic)
    DocumentReference transRef = _firestore.collection('transactions').doc();
    batch.set(transRef, {
      'type': 'match_win',
      'teamId': winningTeamId,
      'amount': 0, // No money involved in win, just points
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}


