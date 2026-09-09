import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../team_repository.dart';

/// Coordinates player rosters, guest registrations, roster syncing, and duplicate player checks.
class TournamentRosterCoordinator {
  final SupabaseClient? _client;
  final TeamRepository? _teamRepository;

  TournamentRosterCoordinator({
    SupabaseClient? client,
    TeamRepository? teamRepository,
  })  : _client = client,
        _teamRepository = teamRepository;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  TeamRepository get _teamRepo => _teamRepository ?? TeamRepository();

  /// Fetch player rosters for home and away teams in a championship (registered players + guests).
  Future<Map<String, List<String>>> fetchRosters(
    String championshipId,
    String homeTeamId,
    String awayTeamId,
  ) async {
    final homePlayers = await fetchTeamFullRosterNames(championshipId, homeTeamId);
    final awayPlayers = await fetchTeamFullRosterNames(championshipId, awayTeamId);
    return {'home': homePlayers, 'away': awayPlayers};
  }

  /// Fetches full roster member and guest names for a single team.
  Future<List<String>> fetchTeamFullRosterNames(
    String championshipId,
    String teamId,
  ) async {
    if (teamId.isEmpty) return [];
    final Set<String> names = {};

    try {
      final roster = await _supabase
          .from('championship_rosters')
          .select()
          .eq('championship_id', championshipId)
          .eq('team_id', teamId)
          .maybeSingle();

      if (roster != null) {
        final rosterId = roster['id']?.toString();

        // 1. Guests from championship_rosters flat arrays
        final guestNamesRaw =
            roster['guest_names'] ?? roster['player_names'] ?? [];
        if (guestNamesRaw is List) {
          for (var g in guestNamesRaw) {
            if (g != null && g.toString().trim().isNotEmpty) {
              names.add(g.toString().trim());
            }
          }
        }

        // 2. Guests from championship_roster_guests table
        if (rosterId != null) {
          try {
            final guestRows = await _supabase
                .from('championship_roster_guests')
                .select('guest_name')
                .eq('roster_id', rosterId);
            for (var row in guestRows) {
              final gName = row['guest_name']?.toString().trim();
              if (gName != null && gName.isNotEmpty) {
                names.add(gName);
              }
            }
          } catch (e) {
            debugPrint('championship_roster_guests notice: $e');
          }
        }

        // 3. Registered players from championship_roster_players joined with users table
        List<String> playerIds = [];
        if (rosterId != null) {
          try {
            final playerRows = await _supabase
                .from('championship_roster_players')
                .select('player_id')
                .eq('roster_id', rosterId);
            for (var row in playerRows) {
              final pId = row['player_id']?.toString();
              if (pId != null && pId.isNotEmpty) {
                playerIds.add(pId);
              }
            }
          } catch (e) {
            debugPrint('championship_roster_players notice: $e');
          }
        }

        if (playerIds.isEmpty) {
          final pIdsRaw = roster['player_ids'];
          if (pIdsRaw is List) {
            playerIds = pIdsRaw
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        }

        if (playerIds.isNotEmpty) {
          try {
            final userRows = await _supabase
                .from('users')
                .select('name')
                .inFilter('id', playerIds);
            for (var u in userRows) {
              final uName = u['name']?.toString().trim();
              if (uName != null && uName.isNotEmpty) {
                names.add(uName);
              }
            }
          } catch (e) {
            debugPrint('Users fetch notice for roster: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching roster for team $teamId: $e');
    }

    // 4. Fallback if roster table is unpopulated: fetch team member names from team_members/users
    if (names.isEmpty && teamId.isNotEmpty) {
      try {
        final uids = await _teamRepo.getTeamMemberUids(teamId);
        if (uids.isNotEmpty) {
          final userRows = await _supabase
              .from('users')
              .select('name')
              .inFilter('id', uids)
              .limit(uids.length);
          for (var u in userRows) {
            final uName = u['name']?.toString().trim();
            if (uName != null && uName.isNotEmpty) {
              names.add(uName);
            }
          }
        }
      } catch (_) {}
    }

    return names.toList();
  }

  /// Fetch player IDs and guest names for a single team in a championship roster.
  Future<Map<String, dynamic>> getSingleTeamRoster(
    String championshipId,
    String teamId,
  ) async {
    try {
      final roster = await _supabase
          .from('championship_rosters')
          .select()
          .eq('championship_id', championshipId)
          .eq('team_id', teamId)
          .maybeSingle();

      if (roster != null) {
        final rosterId = roster['id'].toString();
        List<String> playerIdsList = [];

        try {
          final playerRows = await _supabase
              .from('championship_roster_players')
              .select('player_id')
              .eq('roster_id', rosterId);
          if (playerRows.isNotEmpty) {
            playerIdsList =
                playerRows.map((r) => r['player_id'].toString()).toList();
          }
        } catch (_) {}

        if (playerIdsList.isEmpty) {
          final playerIdsRaw = roster['player_ids'] ?? [];
          if (playerIdsRaw is List) {
            playerIdsList = List<String>.from(playerIdsRaw);
          }
        }

        final guestNamesRaw =
            roster['guest_names'] ?? roster['player_names'] ?? [];

        return {
          'player_ids': playerIdsList,
          'guest_names': guestNamesRaw is List
              ? List<String>.from(guestNamesRaw)
              : <String>[],
        };
      }
    } catch (e) {
      debugPrint('Error fetching single team roster: $e');
    }
    return {'player_ids': <String>[], 'guest_names': <String>[]};
  }

  /// Update single team roster (player_ids & guest_names) in a championship.
  Future<bool> updateSingleTeamRoster({
    required String championshipId,
    required String teamId,
    required List<String> playerIds,
    required List<String> guestNames,
  }) async {
    try {
      final existing = await _supabase
          .from('championship_rosters')
          .select('id')
          .eq('championship_id', championshipId)
          .eq('team_id', teamId)
          .maybeSingle();

      String rosterId;
      final payload = {
        'championship_id': championshipId,
        'team_id': teamId,
        'guest_names': guestNames,
      };

      if (existing != null) {
        rosterId = existing['id'].toString();
        await _supabase
            .from('championship_rosters')
            .update(payload)
            .eq('id', rosterId);
      } else {
        final inserted = await _supabase
            .from('championship_rosters')
            .insert(payload)
            .select('id')
            .single();
        rosterId = inserted['id'].toString();
      }

      // Separate player_ids into championship_roster_players table
      try {
        await _supabase
            .from('championship_roster_players')
            .delete()
            .eq('roster_id', rosterId);

        if (playerIds.isNotEmpty) {
          final rosterPlayerRows = playerIds
              .map((pId) => {
                    'roster_id': rosterId,
                    'player_id': pId,
                  })
              .toList();

          await _supabase
              .from('championship_roster_players')
              .insert(rosterPlayerRows);
        }
      } catch (err) {
        debugPrint('championship_roster_players sync notice: $err');
      }

      debugPrint('Tournament roster updated successfully for team $teamId');
      return true;
    } catch (e) {
      debugPrint('Error updating tournament roster: $e');
      return false;
    }
  }

  /// Insert championship roster.
  Future<void> insertChampionshipRoster({
    required String championshipId,
    required String teamId,
    required List<String> guestNames,
    List<String> playerIds = const [],
  }) async {
    await _supabase.from('championship_rosters').insert({
      'championship_id': championshipId,
      'team_id': teamId,
      'player_ids': playerIds,
      'guest_names': guestNames,
    });
  }

  /// Check for duplicate players or guests across other teams in the same championship.
  Future<List<String>> checkDuplicatePlayersInChampionship({
    required String championshipId,
    required String currentTeamId,
    required List<String> playerIds,
    required List<String> guestNames,
  }) async {
    final List<String> duplicateNames = [];
    try {
      final rosters = await _supabase
          .from('championship_rosters')
          .select('id, team_id, guest_names, player_ids')
          .eq('championship_id', championshipId)
          .neq('team_id', currentTeamId);

      final otherRosters = List<Map<String, dynamic>>.from(rosters as List);
      final Set<String> registeredPlayerIds = {};
      final Set<String> registeredGuestNames = {};
      final List<String> otherRosterIds = [];

      for (var r in otherRosters) {
        final rosterId = r['id'].toString();
        otherRosterIds.add(rosterId);
        final pIds = r['player_ids'] as List? ?? [];
        for (var p in pIds) {
          if (p != null && p.toString().isNotEmpty) {
            registeredPlayerIds.add(p.toString());
          }
        }
        final gNames = r['guest_names'] as List? ?? [];
        for (var g in gNames) {
          if (g != null && g.toString().trim().isNotEmpty) {
            registeredGuestNames.add(g.toString().trim().toLowerCase());
          }
        }
      }

      // Batch fetch all players across other rosters in 1 query instead of N+1
      if (otherRosterIds.isNotEmpty) {
        try {
          final rp = await _supabase
              .from('championship_roster_players')
              .select('player_id')
              .inFilter('roster_id', otherRosterIds);
          for (var item in (rp as List)) {
            final pId = item['player_id']?.toString();
            if (pId != null && pId.isNotEmpty) registeredPlayerIds.add(pId);
          }
        } catch (_) {}
      }

      // Batch fetch duplicate user names in 1 query instead of loop queries
      final matchingDupIds =
          playerIds.where((p) => registeredPlayerIds.contains(p)).toList();
      if (matchingDupIds.isNotEmpty) {
        try {
          final userDocs = await _supabase
              .from('users')
              .select('name')
              .inFilter('id', matchingDupIds);
          for (var u in (userDocs as List)) {
            final name = u['name']?.toString() ?? 'لاعب مسجل';
            duplicateNames.add(name);
          }
        } catch (_) {
          duplicateNames.add('لاعب مسجل مسبقاً');
        }
      }

      for (final g in guestNames) {
        if (registeredGuestNames.contains(g.trim().toLowerCase())) {
          duplicateNames.add(g.trim());
        }
      }
    } catch (e) {
      debugPrint('Error checking duplicate players in championship: $e');
    }
    return duplicateNames;
  }
}
