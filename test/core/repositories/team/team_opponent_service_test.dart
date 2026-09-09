import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/team/team_opponent_service.dart';

void main() {
  group('TeamOpponentService Tests', () {
    test('parseTeamsWithMembers correctly maps raw database documents', () {
      final sampleRows = [
        {
          'id': 'team_alpha',
          'name': 'Alpha FC',
          'captain_id': 'c1',
          'governorate': 'Cairo',
          'bio': 'Test Bio',
          'elo_rating': 1200,
          'team_members': [
            {
              'user_id': 'u1',
              'users': {'profile_image_url': 'https://img.com/1.png'},
            },
            {
              'user_id': 'u2',
              'users': {'profile_image_url': 'https://img.com/2.png'},
            },
          ],
        },
        'invalid_non_map_row',
      ];

      final teams = TeamOpponentService.parseTeamsWithMembers(sampleRows);

      expect(teams.length, 1);
      expect(teams.first.id, 'team_alpha');
      expect(teams.first.name, 'Alpha FC');
      expect(teams.first.memberUids, ['u1', 'u2']);
      expect(teams.first.playerImages, ['https://img.com/1.png', 'https://img.com/2.png']);
      expect(teams.first.memberUids.length, 2);
    });

    test('parseTeamsWithMembers returns empty list for empty input', () {
      final teams = TeamOpponentService.parseTeamsWithMembers([]);
      expect(teams, isEmpty);
    });
  });
}
