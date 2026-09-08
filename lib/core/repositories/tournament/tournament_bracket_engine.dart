import 'dart:math';
import 'package:uuid/uuid.dart';

/// Pure computation engine for all tournament bracket and fixture algorithms.
/// Contains zero Supabase dependencies — all methods are deterministic and testable.
///
/// Covers:
/// - Knockout bracket capacity and round count calculations
/// - Full bracket match-map generation with BYE auto-advance cascading
/// - Round-Robin league fixture generation (single & two-legs)
/// - Group stage fixture generation
/// - Groups → Knockout seeding with cross-group pairing
class TournamentBracketEngine {
  const TournamentBracketEngine._();

  // ═══════════════════════ Bracket Math ═══════════════════════════════════

  /// Returns the smallest power-of-2 bracket capacity that fits [totalTeams].
  /// Respects [configuredMaxTeams] if it is a valid power-of-2 and ≥ totalTeams.
  static int computeBracketCapacity(int totalTeams, int configuredMaxTeams) {
    const validPowers = {4, 8, 16, 32};
    if (validPowers.contains(configuredMaxTeams) && configuredMaxTeams >= totalTeams) {
      return configuredMaxTeams;
    }
    int p = 4;
    while (p < totalTeams && p < 32) {
      p *= 2;
    }
    return p;
  }

  /// Returns the number of binary-tree rounds for the given [bracketCapacity].
  /// e.g. capacity=8 → 3, capacity=16 → 4, capacity=32 → 5.
  static int computeTotalRounds(int bracketCapacity) {
    return (log(bracketCapacity) / log(2)).round();
  }

  // ═══════════════════════ Knockout Bracket ═══════════════════════════════

  /// Builds the full knockout match list (with BYE auto-advance cascading).
  ///
  /// [slots] length must equal [bracketCapacity]. Null entries represent BYE slots.
  /// [teamMap] maps teamId → teamName for display.
  ///
  /// Returns a sorted list of match payloads (round_index ASC) ready for DB insertion.
  static List<Map<String, dynamic>> buildKnockoutMatchList({
    required String championshipId,
    required int bracketCapacity,
    required List<String?> slots,
    required Map<String, String> teamMap,
  }) {
    final int totalRounds = computeTotalRounds(bracketCapacity);
    final int startRoundIndex = totalRounds - 1;

    // Pre-assign stable UUIDs for each (round, matchIndex) pair
    final matchUuidMap = <String, String>{};
    String getMatchId(int r, int m) {
      final key = '${r}_$m';
      return matchUuidMap.putIfAbsent(key, _generateUuid);
    }

    // 1. Initialize all match entries for all rounds
    final matchesMap = <String, Map<String, dynamic>>{};
    for (int r = startRoundIndex; r >= 0; r--) {
      final int matchCount = (pow(2, r)).toInt();
      for (int m = 0; m < matchCount; m++) {
        final matchId = getMatchId(r, m);
        matchesMap[matchId] = {
          'id': matchId,
          'championship_id': championshipId,
          'round_index': r,
          'match_index': m,
          'next_match_id': (r > 0) ? getMatchId(r - 1, m ~/ 2) : null,
          'home_team_id': null,
          'home_team_name': null,
          'away_team_id': null,
          'away_team_name': null,
          'home_score': null,
          'away_score': null,
          'winner_id': null,
        };
      }
    }

    // 2. Populate first round from slots
    final int firstRoundMatches = (pow(2, startRoundIndex)).toInt();
    for (int m = 0; m < firstRoundMatches; m++) {
      final matchId = getMatchId(startRoundIndex, m);
      final matchData = matchesMap[matchId]!;
      final String? homeId = slots[m * 2];
      final String? awayId = slots[m * 2 + 1];

      matchData['home_team_id'] = homeId;
      matchData['home_team_name'] = homeId != null ? teamMap[homeId] : null;
      matchData['away_team_id'] = awayId;
      matchData['away_team_name'] = awayId != null ? teamMap[awayId] : null;

      _tryApplyBye(
        matchData: matchData,
        matchesMap: matchesMap,
        teamMap: teamMap,
        homeId: homeId,
        awayId: awayId,
        matchIndex: m,
      );
    }

    // 3. Cascade BYE auto-advances for intermediate rounds (startRoundIndex-1 → 1)
    bool isSubtreeEmpty(int roundIdx, int matchIdx) {
      final mId = getMatchId(roundIdx, matchIdx);
      final mData = matchesMap[mId];
      if (mData == null) return true;
      if (mData['home_team_id'] != null ||
          mData['away_team_id'] != null ||
          mData['winner_id'] != null) {
        return false;
      }
      if (roundIdx < startRoundIndex) {
        return isSubtreeEmpty(roundIdx + 1, matchIdx * 2) &&
            isSubtreeEmpty(roundIdx + 1, matchIdx * 2 + 1);
      }
      return true;
    }

    for (int r = startRoundIndex - 1; r >= 1; r--) {
      final int matchCount = (pow(2, r)).toInt();
      for (int m = 0; m < matchCount; m++) {
        final matchId = getMatchId(r, m);
        final matchData = matchesMap[matchId]!;
        final homeId = matchData['home_team_id'] as String?;
        final awayId = matchData['away_team_id'] as String?;

        if (homeId != null && awayId == null && isSubtreeEmpty(r + 1, m * 2 + 1)) {
          _tryApplyBye(
            matchData: matchData,
            matchesMap: matchesMap,
            teamMap: teamMap,
            homeId: homeId,
            awayId: null,
            matchIndex: m,
          );
        } else if (homeId == null && awayId != null && isSubtreeEmpty(r + 1, m * 2)) {
          _tryApplyBye(
            matchData: matchData,
            matchesMap: matchesMap,
            teamMap: teamMap,
            homeId: null,
            awayId: awayId,
            matchIndex: m,
          );
        }
      }
    }

    // 4. Sort by round_index ASC to satisfy next_match_id FK constraint on insert
    final result = matchesMap.values.toList()
      ..sort((a, b) => (a['round_index'] as int).compareTo(b['round_index'] as int));
    return result;
  }

  // ═══════════════════════ League (Round-Robin) ════════════════════════════

  /// Generates Round-Robin league fixtures for the given teams.
  /// If [isTwoLegs], a mirrored return-leg set is appended (home↔away swapped).
  ///
  /// Returns match payloads ready for DB insertion (no Supabase calls).
  static List<Map<String, dynamic>> buildLeagueMatchList({
    required String championshipId,
    required List<String> teamIds,
    required Map<String, String> teamMap,
    bool isTwoLegs = false,
  }) {
    final List<String?> teamList = List.from(teamIds);
    if (teamList.length % 2 != 0) teamList.add(null); // dummy BYE team

    final int numTeams = teamList.length;
    final int numWeeks = numTeams - 1;
    final int matchesPerWeek = numTeams ~/ 2;

    final List<Map<String, dynamic>> matches = [];

    for (int week = 0; week < numWeeks; week++) {
      for (int match = 0; match < matchesPerWeek; match++) {
        final homeIdx = (week + match) % (numTeams - 1);
        var awayIdx = (numTeams - 1 - match + week) % (numTeams - 1);
        if (match == 0) awayIdx = numTeams - 1;

        final homeId = teamList[homeIdx];
        final awayId = teamList[awayIdx];

        if (homeId != null && awayId != null) {
          matches.add({
            'id': const Uuid().v4(),
            'championship_id': championshipId,
            'round_index': 0,
            'match_index': matches.length,
            'week_number': week + 1,
            'stage': 'league',
            'home_team_id': homeId,
            'home_team_name': teamMap[homeId] ?? 'فريق $homeId',
            'away_team_id': awayId,
            'away_team_name': teamMap[awayId] ?? 'فريق $awayId',
          });
        }
      }
    }

    if (isTwoLegs) {
      final int firstLegWeeks = numWeeks;
      final firstLeg = List<Map<String, dynamic>>.from(matches);
      for (final m in firstLeg) {
        matches.add({
          'id': const Uuid().v4(),
          'championship_id': championshipId,
          'round_index': 0,
          'match_index': matches.length,
          'week_number': (m['week_number'] as int) + firstLegWeeks,
          'stage': 'league',
          'home_team_id': m['away_team_id'],
          'home_team_name': m['away_team_name'],
          'away_team_id': m['home_team_id'],
          'away_team_name': m['home_team_name'],
        });
      }
    }

    return matches;
  }

  // ═══════════════════════ Group Stage ════════════════════════════════════

  /// Generates group stage fixtures using Round-Robin within each group.
  /// Teams are randomly shuffled then distributed across groups via modulo.
  static List<Map<String, dynamic>> buildGroupMatchList({
    required String championshipId,
    required List<String> teamIds,
    required Map<String, String> teamMap,
    required int numGroups,
  }) {
    const groupNames = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    final shuffled = List<String>.from(teamIds)..shuffle(Random());
    final List<Map<String, dynamic>> matches = [];

    for (int g = 0; g < numGroups; g++) {
      final groupName = groupNames[g];
      final groupTeamIds = [
        for (int i = 0; i < shuffled.length; i++)
          if (i % numGroups == g) shuffled[i],
      ];

      final List<String?> teamList = List.from(groupTeamIds);
      if (teamList.length % 2 != 0) teamList.add(null);

      final int numTeams = teamList.length;
      final int numWeeks = numTeams - 1;
      final int matchesPerWeek = numTeams ~/ 2;

      for (int week = 0; week < numWeeks; week++) {
        for (int match = 0; match < matchesPerWeek; match++) {
          final homeIdx = (week + match) % (numTeams - 1);
          var awayIdx = (numTeams - 1 - match + week) % (numTeams - 1);
          if (match == 0) awayIdx = numTeams - 1;

          final homeId = teamList[homeIdx];
          final awayId = teamList[awayIdx];

          if (homeId != null && awayId != null) {
            matches.add({
              'id': const Uuid().v4(),
              'championship_id': championshipId,
              'round_index': 99,
              'match_index': matches.length,
              'group_name': groupName,
              'week_number': week + 1,
              'stage': 'group_stage',
              'home_team_id': homeId,
              'home_team_name': teamMap[homeId] ?? 'فريق $homeId',
              'away_team_id': awayId,
              'away_team_name': teamMap[awayId] ?? 'فريق $awayId',
            });
          }
        }
      }
    }

    return matches;
  }

  // ═══════════════════════ Groups → Knockout ═══════════════════════════════

  /// Builds the knockout match list from already-qualified teams (from groups stage).
  ///
  /// [qualifiedTeams] must be pre-ordered in cross-group seeding order:
  /// e.g. [A1, B2, B1, A2, C1, D2, D1, C2] for 4 groups × 2 qualifiers.
  /// Null/BYE slots are automatically added to reach the next power-of-2.
  static List<Map<String, dynamic>> buildKnockoutFromQualifiedTeams({
    required String championshipId,
    required List<Map<String, String>> qualifiedTeams,
  }) {
    final int totalKnockoutTeams = qualifiedTeams.length;
    int targetCapacity = 2;
    while (targetCapacity < totalKnockoutTeams) {
      targetCapacity *= 2;
    }

    final slots = List<String?>.generate(
      targetCapacity,
      (i) => i < qualifiedTeams.length ? qualifiedTeams[i]['id'] : null,
    );
    final slotNames = List<String?>.generate(
      targetCapacity,
      (i) => i < qualifiedTeams.length ? qualifiedTeams[i]['name'] : null,
    );

    final int totalRounds = computeTotalRounds(targetCapacity);
    final int startRoundIndex = totalRounds - 1;

    final matchUuidMap = <String, String>{};
    String getMatchId(int r, int m) =>
        matchUuidMap.putIfAbsent('${r}_$m', () => const Uuid().v4());

    final matchesMap = <String, Map<String, dynamic>>{};
    for (int r = startRoundIndex; r >= 0; r--) {
      final int matchCount = (pow(2, r)).toInt();
      for (int m = 0; m < matchCount; m++) {
        final matchId = getMatchId(r, m);
        matchesMap[matchId] = {
          'id': matchId,
          'championship_id': championshipId,
          'round_index': r,
          'match_index': m,
          'next_match_id': (r > 0) ? getMatchId(r - 1, m ~/ 2) : null,
          'stage': 'knockout',
          'home_team_id': null,
          'home_team_name': null,
          'away_team_id': null,
          'away_team_name': null,
          'winner_id': null,
        };
      }
    }

    final int firstRoundMatchCount = (pow(2, startRoundIndex)).toInt();
    for (int m = 0; m < firstRoundMatchCount; m++) {
      final matchId = getMatchId(startRoundIndex, m);
      final matchData = matchesMap[matchId]!;
      final String? homeId = slots[m * 2];
      final String? awayId = slots[m * 2 + 1];

      matchData['home_team_id'] = homeId;
      matchData['home_team_name'] = slotNames[m * 2];
      matchData['away_team_id'] = awayId;
      matchData['away_team_name'] = slotNames[m * 2 + 1];

      if (homeId != null && awayId == null) {
        matchData['winner_id'] = homeId;
        matchData['home_score'] = 0;
        matchData['away_score'] = 0;
        final nextId = matchData['next_match_id'] as String?;
        if (nextId != null && matchesMap.containsKey(nextId)) {
          final next = matchesMap[nextId]!;
          if (m % 2 == 0) {
            next['home_team_id'] = homeId;
            next['home_team_name'] = slotNames[m * 2];
          } else {
            next['away_team_id'] = homeId;
            next['away_team_name'] = slotNames[m * 2];
          }
        }
      } else if (homeId == null && awayId != null) {
        matchData['winner_id'] = awayId;
        matchData['home_score'] = 0;
        matchData['away_score'] = 0;
        final nextId = matchData['next_match_id'] as String?;
        if (nextId != null && matchesMap.containsKey(nextId)) {
          final next = matchesMap[nextId]!;
          if (m % 2 == 0) {
            next['home_team_id'] = awayId;
            next['home_team_name'] = slotNames[m * 2 + 1];
          } else {
            next['away_team_id'] = awayId;
            next['away_team_name'] = slotNames[m * 2 + 1];
          }
        }
      }
    }

    final result = matchesMap.values.toList()
      ..sort((a, b) => (a['round_index'] as int).compareTo(b['round_index'] as int));
    return result;
  }

  // ═══════════════════════ Private Helpers ════════════════════════════════

  /// Applies BYE auto-advance: if one slot is null, the other team wins immediately
  /// and is propagated into the next match slot.
  static void _tryApplyBye({
    required Map<String, dynamic> matchData,
    required Map<String, Map<String, dynamic>> matchesMap,
    required Map<String, String> teamMap,
    required String? homeId,
    required String? awayId,
    required int matchIndex,
  }) {
    if (homeId != null && awayId == null) {
      _advanceWinner(matchData, matchesMap, teamMap, homeId, matchIndex, isHome: true);
    } else if (homeId == null && awayId != null) {
      _advanceWinner(matchData, matchesMap, teamMap, awayId, matchIndex, isHome: false);
    }
  }

  static void _advanceWinner(
    Map<String, dynamic> matchData,
    Map<String, Map<String, dynamic>> matchesMap,
    Map<String, String> teamMap,
    String winnerId,
    int matchIndex, {
    required bool isHome,
  }) {
    matchData['winner_id'] = winnerId;
    matchData['home_score'] = 0;
    matchData['away_score'] = 0;

    final nextMatchId = matchData['next_match_id'] as String?;
    if (nextMatchId != null && matchesMap.containsKey(nextMatchId)) {
      final nextMatch = matchesMap[nextMatchId]!;
      final isHomeSlot = matchIndex % 2 == 0;
      if (isHomeSlot) {
        nextMatch['home_team_id'] = winnerId;
        nextMatch['home_team_name'] = teamMap[winnerId];
      } else {
        nextMatch['away_team_id'] = winnerId;
        nextMatch['away_team_name'] = teamMap[winnerId];
      }
    }
  }

  /// Generates a UUID v4 using random bytes (matches original implementation).
  static String _generateUuid() {
    final rng = Random();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final buf = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) buf.write('-');
      buf.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }
}
