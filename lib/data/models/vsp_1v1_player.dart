class VSP1v1Player {
  final String id;
  final String name;
  final String avatarUrl;
  final int totalPoints;
  final int skillPoints;
  final int goals;
  final int tackles;
  final int titles;
  final int rank;
  final String trend;

  VSP1v1Player({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.totalPoints,
    required this.skillPoints,
    required this.goals,
    required this.tackles,
    this.titles = 0,
    required this.rank,
    this.trend = 'stable',
  });

  factory VSP1v1Player.fromMap(Map<String, dynamic> data, [String? id]) =>
      VSP1v1Player.fromFirestore(data, id ?? (data['id']?.toString() ?? ''));

  factory VSP1v1Player.fromFirestore(Map<String, dynamic> data, String id) {
    return VSP1v1Player(
      id: id,
      name: data['name'] ?? 'Unknown',
      avatarUrl: data['avatarUrl'] ?? '',
      totalPoints: (data['totalPoints'] ?? 0).toInt(),
      skillPoints: (data['skillPoints'] ?? 0).toInt(),
      goals: (data['goals'] ?? 0).toInt(),
      tackles: (data['tackles'] ?? 0).toInt(),
      titles: (data['titles'] ?? 0).toInt(),
      rank: (data['rank'] ?? 99).toInt(),
      trend: data['trend'] ?? 'stable',
    );
  }

  Map<String, dynamic> toMap() => toFirestore();

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'avatarUrl': avatarUrl,
      'totalPoints': totalPoints,
      'skillPoints': skillPoints,
      'goals': goals,
      'tackles': tackles,
      'titles': titles,
      'rank': rank,
      'trend': trend,
    };
  }

  static List<VSP1v1Player> getMockStandings() {
    return [
      VSP1v1Player(id: '1', name: 'Ahmed', avatarUrl: '', totalPoints: 100, skillPoints: 50, goals: 20, tackles: 10, rank: 1),
      VSP1v1Player(id: '2', name: 'Mohamed', avatarUrl: '', totalPoints: 80, skillPoints: 40, goals: 15, tackles: 8, rank: 2),
      VSP1v1Player(id: '3', name: 'Ali', avatarUrl: '', totalPoints: 60, skillPoints: 30, goals: 10, tackles: 5, rank: 3),
      VSP1v1Player(id: '4', name: 'Hassan', avatarUrl: '', totalPoints: 40, skillPoints: 20, goals: 5, tackles: 2, rank: 4),
      VSP1v1Player(id: '5', name: 'Ibrahim', avatarUrl: '', totalPoints: 20, skillPoints: 10, goals: 2, tackles: 1, rank: 5),
    ];
  }
}
