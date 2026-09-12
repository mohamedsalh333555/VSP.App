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
    final tackles = (data['tackles'] ?? 0).toInt();
    final goals = (data['goals'] ?? 0).toInt();
    final skillPoints = (data['skillPoints'] ?? data['skill_points'] ?? data['skills'] ?? 0).toInt();
    final computedPoints = tackles + goals + skillPoints;
    final totalPoints = (data['totalPoints'] ?? data['total_points'] ?? computedPoints).toInt();

    return VSP1v1Player(
      id: id,
      name: data['name'] ?? data['player_name'] ?? 'Unknown',
      avatarUrl: data['avatarUrl'] ?? data['avatar_url'] ?? '',
      totalPoints: totalPoints,
      skillPoints: skillPoints,
      goals: goals,
      tackles: tackles,
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
      VSP1v1Player(id: '1', name: 'أحمد زيزو (الحريف)', avatarUrl: '', totalPoints: 16, skillPoints: 6, goals: 6, tackles: 4, titles: 5, rank: 1, trend: 'up'),
      VSP1v1Player(id: '2', name: 'محمود تريكة', avatarUrl: '', totalPoints: 13, skillPoints: 5, goals: 5, tackles: 3, titles: 3, rank: 2, trend: 'up'),
      VSP1v1Player(id: '3', name: 'كريم بنزيما المعادي', avatarUrl: '', totalPoints: 10, skillPoints: 3, goals: 4, tackles: 3, titles: 2, rank: 3, trend: 'stable'),
      VSP1v1Player(id: '4', name: 'يوسف فانتاسي', avatarUrl: '', totalPoints: 7, skillPoints: 2, goals: 3, tackles: 2, titles: 1, rank: 4, trend: 'down'),
      VSP1v1Player(id: '5', name: 'علي مهارة', avatarUrl: '', totalPoints: 5, skillPoints: 2, goals: 2, tackles: 1, titles: 0, rank: 5, trend: 'stable'),
    ];
  }
}
