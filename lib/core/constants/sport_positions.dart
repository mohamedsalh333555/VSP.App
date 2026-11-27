class VSPConstants {
  /// Centralized Active Sports Control
  /// Currently: Football only. Future sports (e.g. 'Padel') can be enabled here.
  static const List<String> activeSports = ['Football'];
  static const List<String> sports = activeSports;
}

class SportPosition {
  final String code;
  final String nameAr;
  final String nameEn;
  const SportPosition({
    required this.code,
    required this.nameAr,
    required this.nameEn,
  });
}

class SportPositionsRegistry {
  static const Map<String, List<SportPosition>> positions = {
    'Football': [
      SportPosition(code: 'GK', nameAr: 'حارس مرمى', nameEn: 'Goalkeeper'),
      SportPosition(code: 'DF', nameAr: 'مدافع', nameEn: 'Defender'),
      SportPosition(code: 'MF', nameAr: 'وسط', nameEn: 'Midfielder'),
      SportPosition(code: 'FW', nameAr: 'مهاجم', nameEn: 'Forward'),
    ],
    'Padel': [
      SportPosition(code: 'Drive', nameAr: 'يمين (Drive)', nameEn: 'Drive'),
      SportPosition(code: 'Revés', nameAr: 'يسار (Revés)', nameEn: 'Revés'),
      SportPosition(
        code: 'All-Round',
        nameAr: 'شامل (All-Round)',
        nameEn: 'All-Round',
      ),
    ],
    'Basketball': [
      SportPosition(
        code: 'PG',
        nameAr: 'صانع ألعاب (PG)',
        nameEn: 'Point Guard',
      ),
      SportPosition(
        code: 'SG',
        nameAr: 'مدافع مسدد (SG)',
        nameEn: 'Shooting Guard',
      ),
      SportPosition(code: 'SF', nameAr: 'جناح (SF)', nameEn: 'Small Forward'),
      SportPosition(
        code: 'PF',
        nameAr: 'لاعب هجوم قوي (PF)',
        nameEn: 'Power Forward',
      ),
      SportPosition(code: 'C', nameAr: 'لاعب ارتكاز (C)', nameEn: 'Center'),
    ],
    'Volleyball': [
      SportPosition(code: 'Setter', nameAr: 'مُعِد', nameEn: 'Setter'),
      SportPosition(code: 'Spiker', nameAr: 'ضارب', nameEn: 'Spiker'),
      SportPosition(code: 'Libero', nameAr: 'ليبرو', nameEn: 'Libero'),
      SportPosition(code: 'Blocker', nameAr: 'حائط صد', nameEn: 'Blocker'),
    ],
    'Handball': [
      SportPosition(code: 'GK', nameAr: 'حارس مرمى', nameEn: 'Goalkeeper'),
      SportPosition(code: 'Wing', nameAr: 'جناح', nameEn: 'Wing'),
      SportPosition(code: 'Back', nameAr: 'ظهير', nameEn: 'Back'),
      SportPosition(code: 'Pivot', nameAr: 'دائرة', nameEn: 'Pivot'),
      SportPosition(
        code: 'Playmaker',
        nameAr: 'صانع ألعاب',
        nameEn: 'Playmaker',
      ),
    ],
  };

  static String getDefaultPosition(String sport) {
    switch (sport) {
      case 'Padel':
        return 'All-Round';
      case 'Basketball':
        return 'SF';
      case 'Volleyball':
        return 'Spiker';
      case 'Handball':
        return 'Wing';
      case 'Football':
      default:
        return 'FW';
    }
  }

  static List<SportPosition> getPositionsForSport(String sport) {
    return positions[sport] ?? positions['Football']!;
  }
}
