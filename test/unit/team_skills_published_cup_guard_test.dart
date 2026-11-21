import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/team_skills_cup_repository.dart';

void main() {
  test('published cup status is authoritative for registration actions', () {
    expect(TeamSkillsCupRepository.registrationOpen(null), isFalse);
    expect(TeamSkillsCupRepository.registrationOpen({}), isFalse);
    for (final status in ['draft', 'live', 'completed', 'cancelled']) {
      expect(TeamSkillsCupRepository.registrationOpen({'status': status}), isFalse,
          reason: 'a cached or closed cup must not allow new enrollments');
    }
    expect(TeamSkillsCupRepository.registrationOpen({
      'id': 'same-cup', 'status': 'registration',
    }), isTrue);
  });
}
