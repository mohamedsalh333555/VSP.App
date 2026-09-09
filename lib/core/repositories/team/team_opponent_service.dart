import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';
import '../team_repository.dart';
import '../../utils/phone_utils.dart';

/// Helper for searching and querying opponent teams, previous matches, and fake-team verification.
class TeamOpponentService {
  const TeamOpponentService._();

  /// Parses relational Supabase team records containing joined member profiles into Team entities.
  static List<Team> parseTeamsWithMembers(List<dynamic> rows) {
    final List<Team> teams = [];
    for (final doc in rows) {
      if (doc is! Map) continue;
      final teamId = doc['id']?.toString() ?? '';
      final membersList = doc['team_members'] as List? ?? [];
      final List<String> memberUids = [];
      final List<String> playerImages = [];

      for (var m in membersList) {
        final uid = m['user_id']?.toString();
        if (uid != null) memberUids.add(uid);
        final userMap = m['users'];
        if (userMap is Map && userMap['profile_image_url'] != null) {
          playerImages.add(userMap['profile_image_url'].toString());
        }
      }

      final data = Map<String, dynamic>.from(doc);
      data['memberUids'] = memberUids;
      data['playerImages'] = playerImages;
      data['playersCount'] = memberUids.length;

      teams.add(Team.fromFirestore(data, teamId));
    }
    return teams;
  }

  /// Searches opponent teams matching the query string.
  static Future<List<Team>> searchOpponentTeams({
    required SupabaseClient supabase,
    required String query,
  }) async {
    try {
      final response = await supabase
          .from('teams')
          .select('*, team_members(user_id, users(profile_image_url))')
          .or('name.ilike.%$query%,captain_phone.ilike.%$query%');

      return parseTeamsWithMembers(response as List);
    } catch (e) {
      debugPrint('Error searching opponent teams: $e');
      return [];
    }
  }

  /// Retrieves previously played opponent teams.
  static Future<List<Team>> getPreviousOpponents({
    required SupabaseClient supabase,
    required TeamRepository repository,
    required String teamId,
  }) async {
    try {
      final team = await repository.getTeam(teamId);
      if (team == null || team.playedOpponents.isEmpty) return [];

      final response = await supabase
          .from('teams')
          .select('*, team_members(user_id, users(profile_image_url))')
          .inFilter('id', team.playedOpponents);

      return parseTeamsWithMembers(response as List);
    } catch (e) {
      debugPrint('Error getting previous opponents: $e');
      return [];
    }
  }

  /// Fake team protection algorithm ensuring teams have genuine history or verified unique phone numbers.
  static Future<bool> checkIsTeamOfficial({
    required SupabaseClient supabase,
    required TeamRepository repository,
    required String teamId,
  }) async {
    try {
      final team = await repository.getTeam(teamId);
      if (team == null) return false;

      if (team.matchesPlayed > 0) {
        return true;
      }

      final memberUids = await repository.getTeamMemberUids(teamId);
      final captainId = team.captainId.isNotEmpty
          ? team.captainId
          : (memberUids.isNotEmpty ? memberUids.first : '');
      if (captainId.isEmpty) return false;

      final allUids = memberUids.contains(captainId) ? memberUids : [captainId, ...memberUids];
      if (allUids.length < 5) return false;

      final response = await supabase
          .from('users')
          .select('phone')
          .inFilter('id', allUids);

      final phones = (response as List)
          .map((row) => PhoneUtils.normalize(row['phone']?.toString()))
          .where((p) => p != null && p.isNotEmpty)
          .cast<String>()
          .toSet();

      return phones.length >= 5;
    } catch (e) {
      debugPrint('Error checking team official status: $e');
      return false;
    }
  }
}
