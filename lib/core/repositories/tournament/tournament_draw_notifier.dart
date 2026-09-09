import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';

/// Handles sending tournament draw notification alerts to players and team members.
class TournamentDrawNotifier {
  final SupabaseClient? _client;
  final Future<List<Team>> Function(List<String> ids)? _getTeamsByIds;

  TournamentDrawNotifier({
    SupabaseClient? client,
    Future<List<Team>> Function(List<String> ids)? getTeamsByIds,
  })  : _client = client,
        _getTeamsByIds = getTeamsByIds;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<List<Team>> _fetchTeams(List<String> ids) async {
    if (_getTeamsByIds != null) return _getTeamsByIds(ids);
    if (ids.isEmpty) return [];
    try {
      final response = await _supabase
          .from('teams')
          .select('*, team_members(user_id, users(profile_image_url))')
          .inFilter('id', ids);

      final List<Team> teams = [];
      for (final doc in (response as List)) {
        final teamId = doc['id'].toString();
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
    } catch (e) {
      debugPrint('Error getting teams by IDs in draw notifier: $e');
      return [];
    }
  }

  /// Sends draw notification to members of all teams in the championship.
  Future<void> sendDrawNotifications(String championshipId) async {
    try {
      final champ = await _supabase
          .from('championships')
          .select('name')
          .eq('id', championshipId)
          .maybeSingle();
      if (champ == null) return;
      final champName = champ['name']?.toString() ?? 'البطولة';

      final response = await _supabase
          .from('tournament_matches')
          .select('home_team_id, away_team_id, home_team_name, away_team_name')
          .eq('championship_id', championshipId);

      final matchesList = response as List;
      final Set<String> teamIds = {};
      for (final m in matchesList) {
        if (m['home_team_id'] != null) teamIds.add(m['home_team_id'].toString());
        if (m['away_team_id'] != null) teamIds.add(m['away_team_id'].toString());
      }

      if (teamIds.isEmpty) return;

      final allTeams = await _fetchTeams(teamIds.toList());
      final Map<String, Team> teamMap = {for (var t in allTeams) t.id: t};

      final List<Map<String, dynamic>> notificationsToInsert = [];

      for (final matchData in matchesList) {
        final String? homeId = matchData['home_team_id']?.toString();
        final String? awayId = matchData['away_team_id']?.toString();
        final String homeName = matchData['home_team_name']?.toString() ?? '';
        final String awayName = matchData['away_team_name']?.toString() ?? '';

        if (homeId != null && awayId != null) {
          final homeTeam = teamMap[homeId];
          if (homeTeam != null) {
            for (final uid in homeTeam.memberUids) {
              notificationsToInsert.add({
                'user_id': uid,
                'title': ' تم إجراء قرعة البطولة!',
                'body':
                    'فريقك سيواجه فريق ($awayName) في بطولة ($champName). تفقد جدول المباريات لمعرفة الموعد والتفاصيل!',
                'type': 'info',
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'is_read': false,
              });
            }
          }

          final awayTeam = teamMap[awayId];
          if (awayTeam != null) {
            for (final uid in awayTeam.memberUids) {
              notificationsToInsert.add({
                'user_id': uid,
                'title': ' تم إجراء قرعة البطولة!',
                'body':
                    'فريقك سيواجه فريق ($homeName) في بطولة ($champName). تفقد جدول المباريات لمعرفة الموعد والتفاصيل!',
                'type': 'info',
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'is_read': false,
              });
            }
          }
        }
      }

      if (notificationsToInsert.isNotEmpty) {
        await _supabase.from('notifications').insert(notificationsToInsert);
      }
    } catch (e) {
      debugPrint('Error sending draw notifications: $e');
    }
  }
}
