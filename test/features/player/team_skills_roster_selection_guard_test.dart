import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/champion/team_skills_cup_tab.dart';

void main() {
  final roster = <Map<String, dynamic>>[
    for (var i = 0; i < 6; i++) {'uid': 'player-$i'},
  ];
  final five = <String>{
    'player-0', 'player-1', 'player-2', 'player-3', 'player-4',
  };
  bool can({bool verified = true,
    Iterable<Map<String, dynamic>>? available, Set<String>? selected,
    String? goalkeeper = 'player-0', String? representative = 'player-1',
  }) => TeamSkillsCupTab.canSubmitVerifiedRoster(
    rosterVerified: verified,
    rosterOptions: available ?? roster,
    selectedPlayers: selected ?? five,
    goalkeeperId: goalkeeper,
    representativeId: representative,
  );

  test('only five players from a verified current roster may register', () {
    expect(can(), isTrue);
    expect(can(verified: false), isFalse);
    expect(can(selected: const {'player-0', 'player-1', 'player-2'}), isFalse);
    expect(can(selected: const {'player-0', 'player-1', 'player-2',
        'player-3', 'player-4', 'player-5'}), isFalse);
  });
  test('stale or incomplete roster cannot authorize registration', () {
    expect(can(available: const []), isFalse);
    expect(can(available: const [
      {'uid': 'player-0'},{'uid': 'player-1'},{'uid': 'player-2'},
      {'uid': 'player-3'},
    ]), isFalse);
    expect(can(selected: const {'player-0', 'player-1', 'player-2',
      'player-3', 'foreign-player'}), isFalse);
    expect(can(available: const [
      {'uid': 'player-0'},{'uid': 'player-1'},{'uid': 'player-2'},
      {'uid': 'player-3'},{'uid': ' '},{'uid': null},
    ]), isFalse);
  });
  test('goalkeeper and final representative must be selected members', () {
    expect(can(goalkeeper: null), isFalse);
    expect(can(representative: null), isFalse);
    expect(can(goalkeeper: 'outsider'), isFalse);
    expect(can(representative: 'outsider'), isFalse);
    expect(can(selected: const {'player-1', 'player-2', 'player-3',
      'player-4', 'player-5'}), isFalse);
  });
}
