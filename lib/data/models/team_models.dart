import '../../core/utils/elo_calculator.dart';

class Team {
 final String id;
 final String name;
 final String captainId;
 final String captainName;
 final String captainImageUrl;
 final String logoUrl;
 final String date;
 final String stadium;
 final double pricePerPerson;
 final int currentPlayers;
 final int maxPlayers;
 final List<String> playerImages;
 final int points;
 final String trend;
 final String? captainPhone;
 final String sportType;

 // ── Governorate & League Fields ──
 final String governorate;
 final int matchesPlayed;
 final int wins;
 final int draws;
 final int losses;
 final List<String> playedOpponents;
 final List<String> beatenOpponents;
 final List<String> unlockedBadges;
 final int currentWinningStreak;
 final List<String> memberUids;
 final int championshipsWon; // TOURNAMENT Logic: Total trophies won

 // ── Fair Play System ──
 final int fairPlayScore; // Season score (0–100), default 100
 final int lastResetYear; // Year of last annual reset, default 2026

 final bool isOfficial;

 Team({
 required this.id,
 required this.name,
 this.captainId = '',
 required this.captainName,
 required this.captainImageUrl,
 this.logoUrl = '',
 required this.date,
 required this.stadium,
 required this.pricePerPerson,
 required this.currentPlayers,
 required this.maxPlayers,
 this.playerImages = const [],
 this.points = 0,
 this.trend = 'stable',
 this.captainPhone,
 this.sportType = 'Football',
 this.governorate = 'Cairo',
 this.matchesPlayed = 0,
 this.wins = 0,
 this.draws = 0,
 this.losses = 0,
 this.playedOpponents = const [],
 this.beatenOpponents = const [],
 this.unlockedBadges = const [],
 this.currentWinningStreak = 0,
 this.memberUids = const [],
 this.championshipsWon = 0,
 this.fairPlayScore = 100,
 this.lastResetYear = 2026,
 this.isOfficial = false,
 });

 String get rankTitle => EloCalculator.getRankTitle(points);

 factory Team.fromMap(Map<String, dynamic> data, [String? id]) =>
 Team.fromFirestore(data, id ?? (data['id']?.toString() ?? ''));

 factory Team.fromFirestore(Map<String, dynamic> data, String docId) {
 final matches = data['matchesPlayed'] ?? data['matches_played'] ?? 0;
 final members = List<String>.from(data['memberUids'] ?? data['member_uids'] ?? []);
 final bool calculatedOfficial = matches > 0 || members.length >= 5;

 return Team(
 id: docId,
 name: data['name'] ?? '',
 captainId: data['captain_id'] ?? data['captainId'] ?? '',
 captainName: data['captainName'] ?? data['captain_name'] ?? 'Captain',
 captainImageUrl: data['captainImageUrl'] ?? data['captain_image_url'] ?? data['logoUrl'] ?? data['logo_url'] ?? '', 
 logoUrl: data['logoUrl'] ?? data['logo_url'] ?? data['captainImageUrl'] ?? data['captain_image_url'] ?? '',
 date: data['date'] ?? 'Upcoming',
 stadium: data['stadium'] ?? 'TBD',
 pricePerPerson: (data['pricePerPerson'] ?? data['price_per_person'] ?? 50).toDouble(),
 currentPlayers: data['playersCount'] ?? data['players_count'] ?? data['currentPlayers'] ?? data['current_players'] ?? 11,
 maxPlayers: data['maxPlayers'] ?? data['max_players'] ?? 11,
 playerImages: List<String>.from(data['playerImages'] ?? data['player_images'] ?? data['members'] ?? []),
 points: data['points'] ?? 0,
 trend: data['trend'] ?? 'stable',
 captainPhone: data['captainPhone'] ?? data['captain_phone'],
 sportType: data['sportType'] ?? data['sport_type'] ?? 'Football',
 governorate: data['governorate'] ?? 'Cairo',
 matchesPlayed: matches,
 wins: data['wins'] ?? 0,
 draws: data['draws'] ?? 0,
 losses: data['losses'] ?? 0,
 playedOpponents: List<String>.from(data['playedOpponents'] ?? data['played_opponents'] ?? []),
 beatenOpponents: List<String>.from(data['beatenOpponents'] ?? data['beaten_opponents'] ?? []),
 unlockedBadges: List<String>.from(data['unlockedBadges'] ?? data['unlocked_badges'] ?? []),
 currentWinningStreak: data['currentWinningStreak'] ?? data['current_winning_streak'] ?? 0,
 memberUids: members,
 championshipsWon: data['championshipsWon'] ?? data['championships_won'] ?? 0,
 fairPlayScore: data['fairPlayScore'] ?? data['fair_play_score'] ?? 100,
 lastResetYear: data['lastResetYear'] ?? data['last_reset_year'] ?? 2026,
 isOfficial: data['is_official'] ?? data['isOfficial'] ?? calculatedOfficial,
 );
 }

 Map<String, dynamic> toMap() => toFirestore();

 Map<String, dynamic> toFirestore() {
 return {
 'name': name,
 'name_lowercase': name.toLowerCase(),
 'captain_id': captainId,
 'captainId': captainId,
 'captainName': captainName,
 'captainImageUrl': captainImageUrl,
 'logoUrl': logoUrl,
 'date': date,
 'stadium': stadium,
 'pricePerPerson': pricePerPerson,
 'currentPlayers': currentPlayers,
 'maxPlayers': maxPlayers,
 'memberUids': memberUids,
 'playerImages': playerImages,
 'points': points,
 'trend': trend,
 'captainPhone': captainPhone,
 'sportType': sportType,
 'governorate': governorate,
 'matchesPlayed': matchesPlayed,
 'wins': wins,
 'draws': draws,
 'losses': losses,
 'playedOpponents': playedOpponents,
 'beatenOpponents': beatenOpponents,
 'unlockedBadges': unlockedBadges,
 'currentWinningStreak': currentWinningStreak,
 'championshipsWon': championshipsWon,
 'fairPlayScore': fairPlayScore,
 'lastResetYear': lastResetYear,
 };
 }

 Team copyWith({
 String? id,
 String? name,
 String? captainId,
 String? captainName,
 String? captainImageUrl,
 String? date,
 String? stadium,
 double? pricePerPerson,
 int? currentPlayers,
 int? maxPlayers,
 List<String>? playerImages,
 int? points,
 String? trend,
 String? captainPhone,
 String? governorate,
 int? matchesPlayed,
 int? wins,
 int? draws,
 int? losses,
 List<String>? playedOpponents,
 List<String>? beatenOpponents,
 int? championshipsWon,
 String? sportType,
 int? fairPlayScore,
 int? lastResetYear,
 List<String>? unlockedBadges,
 }) {
 return Team(
 id: id ?? this.id,
 name: name ?? this.name,
 captainId: captainId ?? this.captainId,
 captainName: captainName ?? this.captainName,
 captainImageUrl: captainImageUrl ?? this.captainImageUrl,
 date: date ?? this.date,
 stadium: stadium ?? this.stadium,
 pricePerPerson: pricePerPerson ?? this.pricePerPerson,
 currentPlayers: currentPlayers ?? this.currentPlayers,
 maxPlayers: maxPlayers ?? this.maxPlayers,
 playerImages: playerImages ?? this.playerImages,
 points: points ?? this.points,
 trend: trend ?? this.trend,
 captainPhone: captainPhone ?? this.captainPhone,
 governorate: governorate ?? this.governorate,
 matchesPlayed: matchesPlayed ?? this.matchesPlayed,
 wins: wins ?? this.wins,
 draws: draws ?? this.draws,
 losses: losses ?? this.losses,
 playedOpponents: playedOpponents ?? this.playedOpponents,
 beatenOpponents: beatenOpponents ?? this.beatenOpponents,
 championshipsWon: championshipsWon ?? this.championshipsWon,
 sportType: sportType ?? this.sportType,
 fairPlayScore: fairPlayScore ?? this.fairPlayScore,
 lastResetYear: lastResetYear ?? this.lastResetYear,
 unlockedBadges: unlockedBadges ?? this.unlockedBadges,
 );
 }


}


/// Model representing a team registered in a Matchup booking
class MatchupTeam {
  final String id;
  final String bookingId;
  final String teamId;
  final String teamName;
  final String logoUrl;
  final String captainId;
  final String addedByUserId;
  final DateTime joinedAt;

  MatchupTeam({
    required this.id,
    required this.bookingId,
    required this.teamId,
    required this.teamName,
    this.logoUrl = '',
    this.captainId = '',
    required this.addedByUserId,
    required this.joinedAt,
  });

  factory MatchupTeam.fromMap(Map<String, dynamic> map) {
    final teamData = map['teams'] is Map ? map['teams'] as Map<String, dynamic> : null;
    return MatchupTeam(
      id: map['id']?.toString() ?? '',
      bookingId: map['booking_id']?.toString() ?? '',
      teamId: map['team_id']?.toString() ?? '',
      teamName: teamData?['name']?.toString() ?? map['team_name']?.toString() ?? 'Team',
      logoUrl: teamData?['logo_url']?.toString() ?? map['logo_url']?.toString() ?? '',
      captainId: teamData?['captain_id']?.toString() ?? map['captain_id']?.toString() ?? '',
      addedByUserId: map['added_by_user_id']?.toString() ?? '',
      joinedAt: map['joined_at'] != null ? DateTime.parse(map['joined_at'].toString()).toLocal() : DateTime.now(),
    );
  }
}

/// Model representing a recorded match result in a Matchup session
class MatchupResult {
  final String id;
  final String bookingId;
  final String teamAId;
  final String teamBId;
  final String outcome; // 'team_a_win', 'team_b_win', 'draw'
  final String recordedBy;
  final DateTime createdAt;

  MatchupResult({
    required this.id,
    required this.bookingId,
    required this.teamAId,
    required this.teamBId,
    required this.outcome,
    required this.recordedBy,
    required this.createdAt,
  });

  factory MatchupResult.fromMap(Map<String, dynamic> map) {
    return MatchupResult(
      id: map['id']?.toString() ?? '',
      bookingId: map['booking_id']?.toString() ?? '',
      teamAId: map['team_a_id']?.toString() ?? '',
      teamBId: map['team_b_id']?.toString() ?? '',
      outcome: map['outcome']?.toString() ?? 'draw',
      recordedBy: map['recorded_by']?.toString() ?? '',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'].toString()).toLocal() : DateTime.now(),
    );
  }
}

/// Model representing historic Head-to-Head record between two teams
class TeamHeadToHead {
  final String teamAId;
  final String teamBId;
  final int teamAWins;
  final int teamBWins;
  final int draws;
  final DateTime updatedAt;

  TeamHeadToHead({
    required this.teamAId,
    required this.teamBId,
    required this.teamAWins,
    required this.teamBWins,
    required this.draws,
    required this.updatedAt,
  });

  int get totalMatches => teamAWins + teamBWins + draws;

  factory TeamHeadToHead.fromMap(Map<String, dynamic> map) {
    return TeamHeadToHead(
      teamAId: map['team_a_id']?.toString() ?? '',
      teamBId: map['team_b_id']?.toString() ?? '',
      teamAWins: (map['team_a_wins'] as num?)?.toInt() ?? 0,
      teamBWins: (map['team_b_wins'] as num?)?.toInt() ?? 0,
      draws: (map['draws'] as num?)?.toInt() ?? 0,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'].toString()).toLocal() : DateTime.now(),
    );
  }
}

/// Dynamic Standings Item calculated on-the-fly for Matchups
class MatchupStandingsItem {
  final String teamId;
  final String teamName;
  final String logoUrl;
  final int matchesPlayed;
  final int wins;
  final int draws;
  final int losses;
  final int points;

  MatchupStandingsItem({
    required this.teamId,
    required this.teamName,
    this.logoUrl = '',
    required this.matchesPlayed,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.points,
  });
}
