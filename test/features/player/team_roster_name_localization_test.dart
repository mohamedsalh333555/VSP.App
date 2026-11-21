import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/team_profile/team_profile_roster_section.dart';

void main() {
  test('roster fallback names are localized and do not invent identities', () {
    expect(TeamProfileRosterSection.publicMemberName(null,isArabic:true), 'لاعب');
    expect(TeamProfileRosterSection.publicMemberName('  ',isArabic:false), 'Player');
    expect(TeamProfileRosterSection.publicMemberName('',isArabic:true), 'لاعب');
    expect(TeamProfileRosterSection.publicMemberName(' أحمد ',isArabic:true), 'أحمد');
    expect(TeamProfileRosterSection.publicMemberName(' Ahmed ',isArabic:false), 'Ahmed');
  });

  test('chip uses the current locale rather than a hardcoded Player label', () {
    final source = File(
      'lib/features/player/widgets/team_profile/team_profile_roster_section.dart',
    ).readAsStringSync();
    expect(source,contains('_buildMemberChip(member, isArabic)'));
    expect(source,contains('publicMemberName(user.name, isArabic: isArabic)'));
    expect(source,isNot(contains("user.name!.trim() : 'Player'")));
  });
}
