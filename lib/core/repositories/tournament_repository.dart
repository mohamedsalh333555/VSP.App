import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../repositories/notification_repository.dart';
import '../../data/models.dart';
import '../models/user_model.dart';

class TournamentRepository {
  final FirebaseFirestore _firestore;

  TournamentRepository({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

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

  Future<bool> updateChampionship(String id, Map<String, dynamic> data) async {
    try {
      final sanitizedData = Map<String, dynamic>.from(data);
      // Protect sensitive fields during update
      sanitizedData.remove('joinedTeams');
      sanitizedData.remove('creatorId');
      sanitizedData.remove('status');
      sanitizedData.remove('ownerId');

      await _firestore.collection('championships').doc(id).update({
        ...sanitizedData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating championship: $e');
      return false;
    }
  }

  // Join a championship with 5-player rule
  Future<bool> joinChampionship(String championshipId, String teamId, {bool skipMemberCheck = false}) async {
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

        if (!skipMemberCheck) {
          final List members = teamData['memberUids'] ?? [];
          final int playerCount = teamData['playersCount'] ?? members.length;
          
          if (playerCount < 5) {
            throw Exception('يجب أن تضم مجموعتك 5 لاعبين على الأقل للمشاركة.');
          }
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
      rethrow;
    }
  }

  // TOURNAMENT Logic: Update championship status
  Future<void> updateChampionshipStatus(String championshipId, String status) async {
    try {
      await _firestore.collection('championships').doc(championshipId).update({
        'status': status,
      });
    } catch (e) {
      debugPrint('Error updating championship status: $e');
    }
  }

  Future<void> crownChampion(String championshipId, String winningTeamId, String winningTeamName) async {
    try {
      final batch = _firestore.batch();
      
      // 1. Mark championship as completed
      batch.update(_firestore.collection('championships').doc(championshipId), {
        'status': 'completed',
        'championTeamId': winningTeamId,
        'championTeamName': winningTeamName,
      });

      // 2. Increment team's trophies and add badge (Prestige, NO ELO POINTS)
      final teamRef = _firestore.collection('teams').doc(winningTeamId);
      batch.update(teamRef, {
        'championshipsWon': FieldValue.increment(1),
        'unlockedBadges': FieldValue.arrayUnion(['cup_winner']),
      });

      await batch.commit();

      // 3. ── Celebration Notifications ──
      _sendCelebrationNotifications(winningTeamId);
    } catch (e) {
      debugPrint('Error crowning champion: $e');
      throw 'Failed to crown champion';
    }
  }

  Future<void> _sendCelebrationNotifications(String teamId) async {
    try {
      final teamDoc = await _firestore.collection('teams').doc(teamId).get();
      if (!teamDoc.exists) return;

      final List memberUids = List.from(teamDoc.data()?['memberUids'] ?? []);
      for (final uid in memberUids) {
        await NotificationRepository().sendNotification(
          uid.toString(),
          AppNotification(
            id: '',
            title: "🏆 CHAMPIONS!",
            body: "Your team has won the championship! A new trophy has been added to your team profile.",
            type: "info",
            createdAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending celebration notifications: $e');
    }
  }

  // TOURNAMENT Logic: Fetch joined teams for dashboard
  Future<List<Team>> getTeamsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final query = await _firestore.collection('teams')
          .where(FieldPath.documentId, whereIn: ids)
          .get();
      
      return query.docs.map((d) => Team.fromFirestore(d.data(), d.id)).toList();
    } catch (e) {
      debugPrint('Error getting teams by IDs: $e');
      return [];
    }
  }

  // ==================== TOURNAMENT BRACKET ENGINE ====================

  Future<void> generateFixtures(String championshipId) async {
    try {
      final champDoc = await _firestore.collection('championships').doc(championshipId).get();
      if (!champDoc.exists) throw 'Championship not found';

      final champData = champDoc.data() as Map<String, dynamic>;
      final List<String> teamIds = List<String>.from(champData['joinedTeams'] ?? []);

      int totalTeams = teamIds.length;
      if (totalTeams < 2) throw 'At least 2 teams are required to start a tournament.';

      // 1. Calculate next power of 2 below N (e.g. N=10 -> P=8)
      int targetP2 = 1;
      while (targetP2 * 2 <= totalTeams) {
        targetP2 *= 2;
      }

      // If N=10, P=8. Matches in R0 = 10 - 8 = 2. Teams in R0 = 4.
      int numOpeningMatches = totalTeams - targetP2;
      int numTeamsR0 = numOpeningMatches * 2;
      int numByes = totalTeams - numTeamsR0;

      final teams = await getTeamsByIds(teamIds);
      final teamMap = {for (var t in teams) t.id: t.name};
      final shuffledIds = List<String>.from(teamIds)..shuffle(Random());

      final batch = _firestore.batch();
      final matchesCollection = _firestore.collection('tournament_matches');

      String getMatchId(int r, int m) => '${championshipId}_R${r}_M$m';

      // 2. Generate Opening Round (R0)
      for (int m = 0; m < numOpeningMatches; m++) {
        final docRef = matchesCollection.doc(getMatchId(0, m));
        String homeId = shuffledIds[m * 2];
        String awayId = shuffledIds[m * 2 + 1];

        final matchData = TournamentMatch(
          id: docRef.id,
          championshipId: championshipId,
          roundIndex: 0,
          matchIndex: m,
          nextMatchId: getMatchId(1, m ~/ 2), 
          homeTeamId: homeId,
          homeTeamName: teamMap[homeId],
          awayTeamId: awayId,
          awayTeamName: teamMap[awayId],
        );
        batch.set(docRef, matchData.toFirestore());
      }

      // 3. Generate main bracket rounds (R1...Final)
      int totalBracketRounds = (log(targetP2) / log(2)).round();
      for (int r = 1; r <= totalBracketRounds; r++) {
        int matchCount = (targetP2 / pow(2, r)).toInt();
        for (int m = 0; m < matchCount; m++) {
          final docRef = matchesCollection.doc(getMatchId(r, m));
          String? nextMatchId = (matchCount > 1) ? getMatchId(r + 1, m ~/ 2) : null;

          String? homeId, homeName, awayId, awayName;

          // Filling Round 1 (Power of 2 round)
          if (r == 1) {
            // Home Slot
            int slotH = m * 2;
            if (slotH >= numOpeningMatches) {
              // This slot is a BYE
              int byeIndex = slotH - numOpeningMatches + numTeamsR0;
              if (byeIndex < shuffledIds.length) {
                homeId = shuffledIds[byeIndex];
                homeName = teamMap[homeId];
              }
            }
            // Away Slot
            int slotA = m * 2 + 1;
            if (slotA >= numOpeningMatches) {
              int byeIndex = slotA - numOpeningMatches + numTeamsR0;
              if (byeIndex < shuffledIds.length) {
                awayId = shuffledIds[byeIndex];
                awayName = teamMap[awayId];
              }
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

      batch.update(champDoc.reference, {'status': 'ongoing'});
      await batch.commit();
      debugPrint('✅ Flexible Bracket Generated for $championshipId: $totalTeams teams');
    } catch (e) {
      debugPrint('Error generating fixtures: $e');
      rethrow;
    }
  }

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

        transaction.update(matchRef, {
          'homeScore': homeScore,
          'awayScore': awayScore,
          'winnerId': winnerId,
        });

        if (nextMatchId != null) {
          final nextMatchRef = _firestore.collection('tournament_matches').doc(nextMatchId);

          String slotField = (matchIndex % 2 == 0) ? 'home' : 'away';

          transaction.update(nextMatchRef, {
            '${slotField}TeamId': winnerId,
            '${slotField}TeamName': winnerName,
          });
        } else {
          // ── Final Match: Crown the Champion ──
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

          // ── Celebration Notifications (Final Match) ──
          _sendCelebrationNotifications(winnerId);
        }
      });
    } catch (e) {
      debugPrint('Error updating tournament match score: $e');
      rethrow;
    }
  }

  Stream<List<TournamentMatch>> getTournamentMatches(String championshipId) {
    return _firestore
        .collection('tournament_matches')
        .where('championshipId', isEqualTo: championshipId)
        .snapshots()
        .map((snapshot) {
      final matches = snapshot.docs
          .map((doc) => TournamentMatch.fromFirestore(doc.data(), doc.id))
          .toList();
      matches.sort((a, b) {
        if (a.roundIndex != b.roundIndex) return b.roundIndex.compareTo(a.roundIndex);
        return a.matchIndex.compareTo(b.matchIndex);
      });
      return matches;
    });
  }
}
