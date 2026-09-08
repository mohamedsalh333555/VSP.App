import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/team/team_payload_builder.dart';

void main() {
  group('TeamPayloadBuilder', () {
    test('buildCreatePayload constructs valid team schema map', () {
      final input = {
        'name': 'Golden Eagles',
        'memberUids': ['user-1', 'user-2'],
        'logoUrl': 'https://example.com/logo.png',
        'primaryColor': '#FF0000',
        'secondaryColor': '#0000FF',
        'city': 'Nasr City',
        'governorate': 'Cairo',
        'bio': 'Strongest amateur football team',
        'preferredFormation': '3-1-1',
      };

      final payload = TeamPayloadBuilder.buildCreatePayload(input);
      expect(payload['name'], equals('Golden Eagles'));
      expect(payload['captain_id'], equals('user-1'));
      expect(payload['logo_url'], equals('https://example.com/logo.png'));
      expect(payload['primary_color'], equals('#FF0000'));
      expect(payload['secondary_color'], equals('#0000FF'));
      expect(payload['city'], equals('Nasr City'));
      expect(payload['governorate'], equals('Cairo'));
      expect(payload['bio'], equals('Strongest amateur football team'));
      expect(payload['preferred_formation'], equals('3-1-1'));
      expect(payload['elo_rating'], equals(1200));
      expect(payload['points'], equals(0));
      expect(payload['is_active'], isTrue);
    });

    test('buildUpdatePayload extracts only provided fields', () {
      final input = {
        'name': 'Updated Eagles',
        'primaryColor': '#111111',
      };

      final updatePayload = TeamPayloadBuilder.buildUpdatePayload(input);
      expect(updatePayload['name'], equals('Updated Eagles'));
      expect(updatePayload['primary_color'], equals('#111111'));
      expect(updatePayload.containsKey('bio'), isFalse);
      expect(updatePayload.containsKey('city'), isFalse);
    });

    test('calculateHeadToHead calculates wins, draws and total correctly', () {
      final rows = [
        {
          'winner_team_id': 'team-1',
          'final_outcome': 'team_a_win',
          'player_team_id': 'team-1',
        },
        {
          'winner_team_id': 'team-2',
          'final_outcome': 'team_b_win',
          'player_team_id': 'team-1',
        },
        {
          'winner_team_id': null,
          'final_outcome': 'draw',
          'player_team_id': 'team-1',
        },
      ];

      final stats = TeamPayloadBuilder.calculateHeadToHead(rows, 'team-1', 'team-2');
      expect(stats['teamAWins'], equals(1));
      expect(stats['teamBWins'], equals(1));
      expect(stats['draws'], equals(1));
      expect(stats['totalMatches'], equals(3));
    });
  });
}
