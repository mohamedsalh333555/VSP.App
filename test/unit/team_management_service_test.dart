import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/my_team/team_management_service.dart';

void main() {
  group('TeamManagementService Unit Tests', () {
    final captainUser = UserModel(
      uid: 'capt_123',
      name: 'Ahmed Hassan',
      email: 'ahmed@vsp.app',
      phone: '01012345678',
      role: 'player',
      governorate: 'Cairo',
      profileImageUrl: 'https://vsp.app/captain.jpg',
    );

    final member1 = UserModel(
      uid: 'mem_1',
      name: 'Mohamed Salah',
      email: 'salah@vsp.app',
      role: 'player',
      profileImageUrl: 'https://vsp.app/salah.jpg',
    );

    final member2 = UserModel(
      uid: 'mem_2',
      name: 'Zizo',
      email: 'zizo@vsp.app',
      role: 'player',
      profileImageUrl: 'https://vsp.app/zizo.jpg',
    );

    test('buildCreateTeamPayload sets captain and member lists accurately', () {
      final payload = TeamManagementService.buildCreateTeamPayload(
        name: 'The Pharaohs',
        sportType: 'Football',
        user: captainUser,
        logoUrl: 'https://vsp.app/pharaohs.png',
        members: [member1, member2],
      );

      expect(payload['name'], 'The Pharaohs');
      expect(payload['sportType'], 'Football');
      expect(payload['captainName'], 'Ahmed Hassan');
      expect(payload['captainPhone'], '01012345678');
      expect(payload['memberUids'], ['capt_123', 'mem_1', 'mem_2']);
      expect(payload['playerImages'], [
        'https://vsp.app/captain.jpg',
        'https://vsp.app/salah.jpg',
        'https://vsp.app/zizo.jpg',
      ]);
      expect(payload['playersCount'], 3);
      expect(payload['governorate'], 'Cairo');
    });

    test('buildUpdateTeamPayload preserves original captain and updates roster', () {
      final existingTeam = Team(
        id: 'team_xyz',
        name: 'Old Name',
        sportType: 'Football',
        captainId: 'capt_123',
        captainName: 'Ahmed Hassan',
        captainImageUrl: 'https://vsp.app/captain.jpg',
        date: 'Today',
        stadium: 'Pitch 1',
        pricePerPerson: 50.0,
        currentPlayers: 2,
        maxPlayers: 10,
        memberUids: ['capt_123', 'mem_old'],
        playerImages: ['https://vsp.app/old.jpg'],
        logoUrl: 'https://vsp.app/old_logo.jpg',
      );

      final payload = TeamManagementService.buildUpdateTeamPayload(
        name: 'Updated Pharaohs',
        sportType: 'Padel',
        existingTeam: existingTeam,
        user: captainUser,
        members: [member1],
      );

      expect(payload['name'], 'Updated Pharaohs');
      expect(payload['sportType'], 'Padel');
      expect(payload['memberUids'], ['capt_123', 'mem_1']);
      expect(payload['playersCount'], 2);
    });

    test('formatTeamErrorMessage formats active tournament lockout correctly', () {
      expect(
        TeamManagementService.formatTeamErrorMessage(
          'Exception: active_match_or_tournament_error locked',
          isArabic: true,
        ),
        contains('لا يمكن إتمام العملية'),
      );

      expect(
        TeamManagementService.formatTeamErrorMessage(
          'team_in_tournament',
          isArabic: false,
        ),
        contains('Cannot complete operation'),
      );
    });
  });
}
