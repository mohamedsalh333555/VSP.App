class VSP1v1Player {
  final String id;
  final String name;
  final String avatarUrl;
  final int totalPoints;
  final int skillPoints;
  final int goals;
  final int tackles; // تدخلات دفاعية ناجحة
  final int titles;
  final int rank;
  final String trend;
  final String? roundReached; // 'champion', 'runner_up', 'semi_final', 'quarter_final', 'round_16', 'round_32'

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
    this.roundReached,
  });

  /// مسمى الدور الإقصائي الذي بلغه اللاعب (بدون أي ألقاب وهمية إذا لم يحدد صراحة)
  String getStageTitle() {
    return switch (roundReached?.toLowerCase()) {
      'champion' || 'بطل' || 'final' || 'نهائي' => '🏆 بطل',
      'runner_up' || 'وصيف' => '🥈 وصيف',
      'semi_final' || 'نصف نهائي' => '🥉 نصف نهائي',
      'quarter_final' || 'ربع نهائي' => '🎖️ ربع نهائي',
      'round_16' || 'دور 16' => 'دور الـ 16',
      'round_32' || 'دور 32' => 'دور الـ 32',
      _ => '', // لا لقب بدون تحديد صريح
    };
  }

  factory VSP1v1Player.fromMap(Map<String, dynamic> data, [String? id]) =>
      VSP1v1Player.fromFirestore(data, id ?? (data['id']?.toString() ?? ''));

  factory VSP1v1Player.fromFirestore(Map<String, dynamic> data, String id) {
    final tackles = (data['tackles'] ?? 0).toInt();
    final goals = (data['goals'] ?? 0).toInt();
    final skillPoints = (data['skills'] ?? data['skill_points'] ?? data['skillPoints'] ?? 0).toInt();
    final computedPoints = tackles + goals + skillPoints;
    final totalPoints = (data['totalPoints'] ?? data['total_points'] ?? computedPoints).toInt();
    final roundReached = data['round_reached']?.toString() ?? data['roundReached']?.toString();

    return VSP1v1Player(
      id: id,
      name: data['name'] ?? data['player_name'] ?? 'لاعب',
      avatarUrl: data['avatarUrl'] ?? data['avatar_url'] ?? '',
      totalPoints: totalPoints,
      skillPoints: skillPoints,
      goals: goals,
      tackles: tackles,
      titles: (data['titles'] ?? 0).toInt(),
      rank: (data['rank'] ?? 99).toInt(),
      trend: data['trend'] ?? 'stable',
      roundReached: roundReached,
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
      'round_reached': roundReached,
    };
  }

  /// أرقام واقعية لبطولة 32 لاعب (البطل يخوض 5 مباريات ويجمع 18-24 نقطة)
  static List<VSP1v1Player> getMockStandings() {
    return [
      VSP1v1Player(
        id: '1',
        name: 'أحمد زيزو (الحريف)',
        avatarUrl: '',
        totalPoints: 21,
        skillPoints: 7,
        goals: 8,
        tackles: 6,
        titles: 1,
        rank: 1,
        trend: 'up',
        roundReached: 'champion',
      ),
      VSP1v1Player(
        id: '2',
        name: 'محمود تريكة',
        avatarUrl: '',
        totalPoints: 17,
        skillPoints: 6,
        goals: 6,
        tackles: 5,
        titles: 0,
        rank: 2,
        trend: 'up',
        roundReached: 'runner_up',
      ),
      VSP1v1Player(
        id: '3',
        name: 'كريم بنزيما المعادي',
        avatarUrl: '',
        totalPoints: 13,
        skillPoints: 4,
        goals: 5,
        tackles: 4,
        titles: 0,
        rank: 3,
        trend: 'stable',
        roundReached: 'semi_final',
      ),
      VSP1v1Player(
        id: '4',
        name: 'يوسف فانتاسي',
        avatarUrl: '',
        totalPoints: 9,
        skillPoints: 3,
        goals: 3,
        tackles: 3,
        titles: 0,
        rank: 4,
        trend: 'down',
        roundReached: 'quarter_final',
      ),
      VSP1v1Player(
        id: '5',
        name: 'علي مهارة',
        avatarUrl: '',
        totalPoints: 6,
        skillPoints: 2,
        goals: 2,
        tackles: 2,
        titles: 0,
        rank: 5,
        trend: 'stable',
        roundReached: 'round_16',
      ),
    ];
  }
}
