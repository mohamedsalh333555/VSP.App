import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/champion/team_skills_request_messages.dart';

void main() {
  test('every registration notice is localized in Arabic and English', () {
    final arabicLetters = RegExp(r'[\u0600-\u06FF]');
    for (final notice in TeamSkillsRequestNotice.values) {
      final ar = TeamSkillsRequestMessages.localize(
          notice, isArabic: true);
      final en = TeamSkillsRequestMessages.localize(
          notice, isArabic: false);
      expect(ar.trim(), isNotEmpty, reason: notice.name);
      expect(en.trim(), isNotEmpty, reason: notice.name);
      expect(arabicLetters.hasMatch(ar), isTrue, reason: notice.name);
      expect(arabicLetters.hasMatch(en), isFalse, reason: notice.name);
      expect(ar, isNot(en), reason: notice.name);
    }
  });

  test('an ambiguous registration response is not presented as a failure',
      () {
    final message = TeamSkillsRequestMessages.localize(
      TeamSkillsRequestNotice.registrationUnconfirmed,
      isArabic: false,
    );
    expect(message, contains('sent'));
    expect(message, contains('could not be confirmed'));
    expect(message, isNot(contains('failed to register')));
  });

  test('an ambiguous withdrawal response asks for verification', () {
    final message = TeamSkillsRequestMessages.localize(
      TeamSkillsRequestNotice.withdrawalUnconfirmed,
      isArabic: false,
    );
    expect(message, contains('submitted'));
    expect(message, contains('could not be confirmed'));
    expect(message, isNot(contains('withdrawal failed')));
  });
}
