/// GoalItem — represents a single goal event in a match
class GoalItem {
  final String id;
  final String teamId;
  final String playerName;
  final bool isOwnGoal;

  GoalItem({
    required this.id,
    required this.teamId,
    required this.playerName,
    this.isOwnGoal = false,
  });

  factory GoalItem.fromMap(Map<String, dynamic> map) {
    return GoalItem(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      teamId: map['team_id']?.toString() ?? map['teamId']?.toString() ?? '',
      playerName: map['player_name']?.toString() ?? map['playerName']?.toString() ?? 'لاعب مجهول',
      isOwnGoal: map['is_own_goal'] == true || map['isOwnGoal'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'team_id': teamId,
      'player_name': playerName,
      'is_own_goal': isOwnGoal,
    };
  }
}

/// Tournament Match — represents a single match in a knockout bracket
class TournamentMatch {
  final String id;
  final String championshipId;
  final int roundIndex; // 0 = Final, 1 = Semi, 2 = Quarters, 3 = Round of 16
  final int matchIndex; // Position within the round
  final String? homeTeamId;
  final String? homeTeamName;
  final String? awayTeamId;
  final String? awayTeamName;
  final int? homeScore;
  final int? awayScore;
  final int? homePenalties;
  final int? awayPenalties;
  final String? winnerId;
  final String? nextMatchId; // ID of the match the winner advances to
  final DateTime? scheduledTime;
  final List<GoalItem> goalDetails;

  // New Fields for Groups & League
  final String? groupName; // 'A', 'B', 'C', 'D'...
  final int? weekNumber; // 1, 2, 3...
  final String stage; // 'preliminary', 'group_stage', 'knockout', 'league'

  TournamentMatch({
    required this.id,
    required this.championshipId,
    required this.roundIndex,
    required this.matchIndex,
    this.homeTeamId,
    this.homeTeamName,
    this.awayTeamId,
    this.awayTeamName,
    this.homeScore,
    this.awayScore,
    this.homePenalties,
    this.awayPenalties,
    this.winnerId,
    this.nextMatchId,
    this.scheduledTime,
    this.goalDetails = const [],
    this.groupName,
    this.weekNumber,
    this.stage = 'knockout',
  });

  bool get isCompleted => winnerId != null || (homeScore != null && awayScore != null);
  bool get isReady => homeTeamId != null && awayTeamId != null;

  String get roundLabel {
    if (stage == 'preliminary') return 'الجولة التمهيدية';
    if (stage == 'group_stage') return 'المجموعة ${groupName ?? "A"} - الأسبوع ${weekNumber ?? 1}';
    if (stage == 'league') return 'الأسبوع ${weekNumber ?? 1}';
    switch (roundIndex) {
      case 0:
        return 'Final';
      case 1:
        return 'Semi-Finals';
      case 2:
        return 'Quarter-Finals';
      case 3:
        return 'Round of 16';
      case 4:
        return 'Round of 32';
      default:
        return 'Round ${roundIndex + 1}';
    }
  }

  TournamentMatch copyWith({
    String? id,
    String? championshipId,
    int? roundIndex,
    int? matchIndex,
    String? homeTeamId,
    String? homeTeamName,
    String? awayTeamId,
    String? awayTeamName,
    int? homeScore,
    int? awayScore,
    int? homePenalties,
    int? awayPenalties,
    String? winnerId,
    String? nextMatchId,
    DateTime? scheduledTime,
    List<GoalItem>? goalDetails,
    String? groupName,
    int? weekNumber,
    String? stage,
  }) {
    return TournamentMatch(
      id: id ?? this.id,
      championshipId: championshipId ?? this.championshipId,
      roundIndex: roundIndex ?? this.roundIndex,
      matchIndex: matchIndex ?? this.matchIndex,
      homeTeamId: homeTeamId ?? this.homeTeamId,
      homeTeamName: homeTeamName ?? this.homeTeamName,
      awayTeamId: awayTeamId ?? this.awayTeamId,
      awayTeamName: awayTeamName ?? this.awayTeamName,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      homePenalties: homePenalties ?? this.homePenalties,
      awayPenalties: awayPenalties ?? this.awayPenalties,
      winnerId: winnerId ?? this.winnerId,
      nextMatchId: nextMatchId ?? this.nextMatchId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      goalDetails: goalDetails ?? this.goalDetails,
      groupName: groupName ?? this.groupName,
      weekNumber: weekNumber ?? this.weekNumber,
      stage: stage ?? this.stage,
    );
  }

  factory TournamentMatch.fromMap(Map<String, dynamic> data, [String? id]) =>
      TournamentMatch.fromFirestore(data, id ?? (data['id']?.toString() ?? ''));

  factory TournamentMatch.fromFirestore(Map<String, dynamic> data, String id) {
    final scheduledTimeVal = data['scheduledTime'] ?? data['scheduled_time'];
    final rawGoals = data['goal_details'] ?? data['goalDetails'] ?? [];
    final List<GoalItem> parsedGoals = (rawGoals is List)
        ? rawGoals.map((g) => GoalItem.fromMap(Map<String, dynamic>.from(g))).toList()
        : [];

    return TournamentMatch(
      id: id,
      championshipId: data['championshipId'] ?? data['championship_id'] ?? '',
      roundIndex: data['roundIndex'] ?? data['round_index'] ?? 0,
      matchIndex: data['matchIndex'] ?? data['match_index'] ?? 0,
      homeTeamId: data['homeTeamId'] ?? data['home_team_id'],
      homeTeamName: data['homeTeamName'] ?? data['home_team_name'],
      awayTeamId: data['awayTeamId'] ?? data['away_team_id'],
      awayTeamName: data['awayTeamName'] ?? data['away_team_name'],
      homeScore: data['homeScore'] ?? data['home_score'],
      awayScore: data['awayScore'] ?? data['away_score'],
      homePenalties: data['homePenalties'] ?? data['home_penalties'],
      awayPenalties: data['awayPenalties'] ?? data['away_penalties'],
      winnerId: data['winnerId'] ?? data['winner_id'],
      nextMatchId: data['nextMatchId'] ?? data['next_match_id'],
      scheduledTime: scheduledTimeVal != null
          ? (scheduledTimeVal is DateTime
              ? scheduledTimeVal.toLocal()
              : DateTime.tryParse(scheduledTimeVal.toString())?.toLocal())
          : null,
      goalDetails: parsedGoals,
      groupName: data['group_name'] ?? data['groupName'],
      weekNumber: data['week_number'] ?? data['weekNumber'],
      stage: data['stage'] ?? 'knockout',
    );
  }

  Map<String, dynamic> toMap() => toFirestore();

  Map<String, dynamic> toFirestore() {
    return {
      'championship_id': championshipId,
      'championshipId': championshipId,
      'round_index': roundIndex,
      'roundIndex': roundIndex,
      'match_index': matchIndex,
      'matchIndex': matchIndex,
      'home_team_id': homeTeamId,
      'homeTeamId': homeTeamId,
      'home_team_name': homeTeamName,
      'homeTeamName': homeTeamName,
      'away_team_id': awayTeamId,
      'awayTeamId': awayTeamId,
      'away_team_name': awayTeamName,
      'awayTeamName': awayTeamName,
      'home_score': homeScore,
      'homeScore': homeScore,
      'away_score': awayScore,
      'awayScore': awayScore,
      'home_penalties': homePenalties,
      'away_penalties': awayPenalties,
      'winner_id': winnerId,
      'winnerId': winnerId,
      'next_match_id': nextMatchId,
      'nextMatchId': nextMatchId,
      'scheduled_time': scheduledTime?.toUtc().toIso8601String(),
      'scheduledTime': scheduledTime?.toUtc().toIso8601String(),
      'goal_details': goalDetails.map((g) => g.toMap()).toList(),
      'group_name': groupName,
      'week_number': weekNumber,
      'stage': stage,
    };
  }
}
