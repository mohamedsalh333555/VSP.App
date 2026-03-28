import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models.dart';
import '../utils/phone_utils.dart';

class TeamRepository {
  final FirebaseFirestore _firestore;

  TeamRepository({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

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

  Future<String?> createTeam(Map<String, dynamic> teamData) async {
    try {
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

  Future<bool> deleteTeam(String teamId) async {
    try {
      await _firestore.collection('teams').doc(teamId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting team: $e');
      return false;
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

  Future<List<Team>> searchOpponentTeams(String query) async {
    try {
      if (query.isEmpty) return [];

      final isPhone = RegExp(r'^\+?[0-9]{3,}$').hasMatch(query);
      Query queryRef = _firestore.collection('teams');

      if (isPhone) {
        final normalized = PhoneUtils.normalize(query);
        queryRef = queryRef.where('captainPhone', isEqualTo: normalized);
      } else {
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
          homeBeaten.add(awayTeamId);
        }
        awayPointsEarned = 0;
      } else if (finalOutcome == MatchOutcome.awayWin) {
        if (awayBeaten.contains(homeTeamId)) {
          awayPointsEarned = 3;
        } else {
          awayPointsEarned = 5;
          if (!awayBadges.contains('Giant Killer')) awayBadges.add('Giant Killer');
          if (isNewForAway && !awayBadges.contains('New Territory')) awayBadges.add('New Territory');
          awayBeaten.add(homeTeamId);
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
      
      transaction.update(_firestore.collection('bookings').doc(bookingId), {
        'status': BookingStatus.completed.name,
        'finalOutcome': finalOutcome.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

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
}
