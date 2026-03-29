import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models.dart';
import '../repositories/notification_repository.dart';

class TeamRepository {
  final FirebaseFirestore _firestore;

  TeamRepository({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

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
      final homeBadges = List<String>.from(homeSnap.data()?['unlockedBadges'] ?? []);
      final awayBadges = List<String>.from(awaySnap.data()?['unlockedBadges'] ?? []);

      bool isNewForHome = !homePlayed.contains(awayTeamId);
      bool isNewForAway = !awayPlayed.contains(homeTeamId);

      int homePointsEarned = 0;
      int awayPointsEarned = 0;

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

  Future<String?> createTeam(Map<String, dynamic> data) async {
    final docRef = await _firestore.collection('teams').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'points': 0,
      'wins': 0,
      'draws': 0,
      'losses': 0,
      'matchesPlayed': 0,
      'currentWinningStreak': 0,
      'unlockedBadges': ['explorer'],
      'playedOpponents': [],
      'beatenOpponents': [],
      'championshipsWon': 0,
    });
    
    // ── Anti-Silent Kidnapping Notification ──
    final List memberUids = List.from(data['memberUids'] ?? []);
    if (memberUids.length > 1) {
      // Loop through all members except the first one (Captain)
      for (int i = 1; i < memberUids.length; i++) {
        _sendJoinNotification(memberUids[i].toString());
      }
    }

    return docRef.id;
  }

  Future<Team?> getTeam(String id) async {
    final doc = await _firestore.collection('teams').doc(id).get();
    if (doc.exists) {
      return Team.fromFirestore(doc.data()!, doc.id);
    }
    return null;
  }

  Stream<List<Team>> getTeams({String? governorate}) {
    Query query = _firestore.collection('teams');
    if (governorate != null) {
      query = query.where('governorate', isEqualTo: governorate);
    }
    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) => Team.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Future<List<Team>> searchOpponentTeams(String query) async {
    final snapshot = await _firestore.collection('teams')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .get();
    return snapshot.docs.map((doc) => Team.fromFirestore(doc.data(), doc.id)).toList();
  }

  Future<List<Team>> getPreviousOpponents(String teamId) async {
    final team = await getTeam(teamId);
    if (team == null || team.playedOpponents.isEmpty) return [];
    
    final snapshot = await _firestore.collection('teams')
        .where(FieldPath.documentId, whereIn: team.playedOpponents)
        .get();
    return snapshot.docs.map((doc) => Team.fromFirestore(doc.data(), doc.id)).toList();
  }

  Future<Map<String, int>> getHeadToHeadStats(String team1Id, String team2Id) async {
    return {'team1Wins': 0, 'draws': 0, 'team2Wins': 0};
  }

  Future<Team?> getTeamByCaptainPhone(String phone) async {
    final snapshot = await _firestore.collection('teams')
        .where('captainPhone', isEqualTo: phone)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return Team.fromFirestore(snapshot.docs.first.data(), snapshot.docs.first.id);
    }
    return null;
  }

  Future<void> addMemberToTeam(String teamId, String userId, String imageUrl) async {
    await _firestore.collection('teams').doc(teamId).update({
      'memberUids': FieldValue.arrayUnion([userId]),
      'playerImages': FieldValue.arrayUnion([imageUrl]),
      'playersCount': FieldValue.increment(1),
    });

    // ── Anti-Silent Kidnapping Notification ──
    _sendJoinNotification(userId);
  }

  Future<void> removeMemberFromTeam(String teamId, String userId, String imageUrl) async {
    await _firestore.collection('teams').doc(teamId).update({
      'memberUids': FieldValue.arrayRemove([userId]),
      'playerImages': FieldValue.arrayRemove([imageUrl]),
      'playersCount': FieldValue.increment(-1),
    });
  }

  Future<bool> updateTeam(String teamId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('teams').doc(teamId).update(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTeam(String teamId) async {
    try {
      await _firestore.collection('teams').doc(teamId).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _sendJoinNotification(String userId) async {
    try {
      await NotificationRepository().sendNotification(
        userId,
        AppNotification(
          id: '',
          title: "⚽ New Team Transfer!",
          body: "You have been drafted to join a new team. Get ready for the next match!",
          type: "info",
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('Error sending join notification: $e');
    }
  }
}
