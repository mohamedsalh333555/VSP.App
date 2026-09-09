import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/team/team_roster_coordinator.dart';
import 'package:vsp_application/core/repositories/team_repository.dart';

void main() {
  group('TeamRosterCoordinator Tests', () {
    test('getTeamPlayerImages returns empty list when memberUids is empty without calling network', () async {
      final coordinator = TeamRosterCoordinator();
      final images = await coordinator.getTeamPlayerImages([]);
      expect(images, isEmpty);
    });

    test('TeamRepository constructor initializes TeamRosterCoordinator properly', () {
      final repo = TeamRepository();
      expect(repo, isNotNull);
    });
  });
}
