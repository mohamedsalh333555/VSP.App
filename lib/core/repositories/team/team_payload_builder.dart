/// Pure stateless payload constructor and calculations for TeamRepository.
class TeamPayloadBuilder {
  const TeamPayloadBuilder._();

  /// Constructs the database row map for creating a new team.
  static Map<String, dynamic> buildCreatePayload(Map<String, dynamic> data) {
    return {
      'name': data['name'],
      'captain_id': (data['memberUids'] as List?)?.first?.toString(),
      'logo_url': data['logoUrl'] ?? data['logo_url'] ?? '',
      'primary_color': data['primaryColor'] ?? data['primary_color'] ?? '#FFFFFF',
      'secondary_color': data['secondaryColor'] ?? data['secondary_color'] ?? '#000000',
      'city': data['city'],
      'governorate': data['governorate'] ?? 'Cairo',
      'bio': data['bio'],
      'preferred_formation': data['preferredFormation'] ?? data['preferred_formation'] ?? '2-2-1',
      'elo_rating': 1200,
      'points': 0,
      'wins': 0,
      'draws': 0,
      'losses': 0,
      'matches_played': 0,
      'current_winning_streak': 0,
      'championships_won': 0,
      'is_active': true,
      'is_blocked': false,
      'is_verified': false,
    };
  }

  /// Constructs the update map with only present fields.
  static Map<String, dynamic> buildUpdatePayload(Map<String, dynamic> data) {
    final pgData = <String, dynamic>{};
    if (data.containsKey('name')) pgData['name'] = data['name'];
    if (data.containsKey('logoUrl')) pgData['logo_url'] = data['logoUrl'];
    if (data.containsKey('logo_url')) pgData['logo_url'] = data['logo_url'];
    if (data.containsKey('primaryColor')) pgData['primary_color'] = data['primaryColor'];
    if (data.containsKey('primary_color')) pgData['primary_color'] = data['primary_color'];
    if (data.containsKey('secondaryColor')) pgData['secondary_color'] = data['secondaryColor'];
    if (data.containsKey('secondary_color')) pgData['secondary_color'] = data['secondary_color'];
    if (data.containsKey('customLogoBase64')) pgData['custom_logo_base64'] = data['customLogoBase64'];
    if (data.containsKey('custom_logo_base64')) pgData['custom_logo_base64'] = data['custom_logo_base64'];
    if (data.containsKey('city')) pgData['city'] = data['city'];
    if (data.containsKey('governorate')) pgData['governorate'] = data['governorate'];
    if (data.containsKey('bio')) pgData['bio'] = data['bio'];
    if (data.containsKey('preferredFormation')) pgData['preferred_formation'] = data['preferredFormation'];
    if (data.containsKey('preferred_formation')) pgData['preferred_formation'] = data['preferred_formation'];
    if (data.containsKey('isActive')) pgData['is_active'] = data['isActive'];
    if (data.containsKey('is_active')) pgData['is_active'] = data['is_active'];
    return pgData;
  }

  /// Calculates head-to-head statistics from raw booking records.
  static Map<String, int> calculateHeadToHead(
    List<dynamic> rows,
    String team1Id,
    String team2Id,
  ) {
    int team1Wins = 0;
    int draws = 0;
    int team2Wins = 0;

    for (var row in rows) {
      if (row is! Map) continue;
      final outcome = row['final_outcome']?.toString() ?? '';
      final hostTeam = row['player_team_id']?.toString() ?? '';
      final awayTeam = row['opponent_team_id']?.toString() ?? '';

      String? winningTeamId;
      if (outcome == 'homeWin' || outcome == 'team_a_win') {
        winningTeamId = hostTeam;
      } else if (outcome == 'awayWin' || outcome == 'team_b_win') {
        winningTeamId = awayTeam;
      }

      if (winningTeamId != null && winningTeamId.isNotEmpty) {
        if (winningTeamId == team1Id) {
          team1Wins++;
        } else if (winningTeamId == team2Id) {
          team2Wins++;
        }
      } else if (outcome == 'draw' || outcome == 'tie') {
        draws++;
      }
    }

    final totalMatches = team1Wins + team2Wins + draws;
    return {
      'teamAWins': team1Wins,
      'draws': draws,
      'teamBWins': team2Wins,
      'totalMatches': totalMatches,
    };
  }
}
