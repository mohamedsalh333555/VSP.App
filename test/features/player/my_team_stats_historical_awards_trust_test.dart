import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/my_team/team_stats_header.dart';

void main() {
  test('retired 1v1 is plainly historical in both locales', () {
    expect(TeamStatsHeader.historicalChampionTitle(isArabic: true),
        'إنجاز تاريخي: بطل 1 ضد 1');
    expect(TeamStatsHeader.historicalChampionTitle(isArabic: false),
        'Historical 1v1 champion');
    for (final ar in [true, false]) {
      final detail = TeamStatsHeader.historicalChampionDescription(isArabic: ar);
      expect(detail, isNotEmpty);
      expect(detail, contains(ar ? 'ليست بطولة جارية' : 'retired'));
      expect(TeamStatsHeader.recordedTitlesLabel(isArabic: ar),
          ar ? 'بطولات مسجلة' : 'Recorded titles');
      expect(TeamStatsHeader.teamPointsExplanation(isArabic: ar),
          contains(ar ? 'المعلقة' : 'pending'));
    }
  });

  test('owned team never promises live ranking or official retired trophy', () {
    final source = File(
      'lib/features/player/widgets/my_team/team_stats_header.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('Home of Official 1v1 Champion!')));
    expect(source, isNot(contains('فريق يضم بطل 1v1 رسمي!')));
    expect(source, isNot(contains('Official Elo Rating')));
    expect(source, contains('historicalChampionTitle(isArabic: isArabic)'));
    expect(source, contains('recordedTitlesLabel(isArabic: isArabic)'));
  });
}
