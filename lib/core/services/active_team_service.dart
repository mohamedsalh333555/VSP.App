import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models.dart';

/// Stores an explicit active-team choice per account on this device.
///
/// Membership and captain permissions remain server-authoritative. This
/// preference only selects which verified membership the UI should display.
class ActiveTeamService {
  const ActiveTeamService._();

  static String _key(String userId) => 'active_team_${userId.trim()}';

  static Future<Team?> resolve({
    required String userId,
    required List<Team> teams,
  }) async {
    if (userId.trim().isEmpty) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (teams.isEmpty) {
        // A deleted/left last team must not remain selected for this account.
        await preferences.remove(_key(userId));
        return null;
      }
      final selectedId = preferences.getString(_key(userId));
      for (final team in teams) {
        if (team.id == selectedId) return team;
      }

      final fallback = teams.first;
      await preferences.setString(_key(userId), fallback.id);
      return fallback;
    } catch (_) {
      // Local preference storage must not hide server-verified memberships.
      return teams.isEmpty ? null : teams.first;
    }
  }

  static Future<bool> select({
    required String userId,
    required String teamId,
    required Iterable<Team> verifiedTeams,
  }) async {
    if (userId.trim().isEmpty || teamId.trim().isEmpty) return false;
    if (!verifiedTeams.any((team) => team.id == teamId)) return false;
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.setString(_key(userId), teamId);
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearForUser(String userId) async {
    if (userId.trim().isEmpty) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_key(userId));
    } catch (_) {
      // Best-effort cleanup only; membership remains server-authoritative.
    }
  }
}
