import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/owner/widgets/tournament/wizard/tournament_wizard_coordinator.dart';

void main() {
  group('TournamentWizardCoordinator Tests', () {
    test('validateSubmission catches empty or invalid fields', () {
      final now = DateTime.now();
      // Empty name
      expect(
        TournamentWizardCoordinator.validateSubmission(
          name: '',
          fee: '100',
          prize: '5000',
          startDate: now,
          endDate: now.add(const Duration(days: 7)),
          selectedTeams: '8',
          isAr: false,
        ),
        'Please enter tournament name',
      );

      // Empty fee (Arabic)
      expect(
        TournamentWizardCoordinator.validateSubmission(
          name: 'Ramadan Cup',
          fee: '',
          prize: '5000',
          startDate: now,
          endDate: now.add(const Duration(days: 7)),
          selectedTeams: '8',
          isAr: true,
        ),
        'يرجى إدخال رسوم الاشتراك في البطولة',
      );

      // End date before start date
      expect(
        TournamentWizardCoordinator.validateSubmission(
          name: 'Ramadan Cup',
          fee: '100',
          prize: '5000',
          startDate: now.add(const Duration(days: 7)),
          endDate: now,
          selectedTeams: '8',
          isAr: false,
        ),
        'End date must be strictly after start date!',
      );

      // Non-power of 2 teams
      expect(
        TournamentWizardCoordinator.validateSubmission(
          name: 'Ramadan Cup',
          fee: '100',
          prize: '5000',
          startDate: now,
          endDate: now.add(const Duration(days: 7)),
          selectedTeams: '10',
          isAr: false,
        ),
        'Number of teams must be a power of 2 (4, 8, 16, 32)!',
      );

      // Valid input
      expect(
        TournamentWizardCoordinator.validateSubmission(
          name: 'Ramadan Cup',
          fee: '100',
          prize: '5000',
          startDate: now,
          endDate: now.add(const Duration(days: 7)),
          selectedTeams: '16',
          isAr: false,
        ),
        isNull,
      );
    });

    test('buildTournamentPayload formats proper payload', () {
      final now = DateTime.now();
      final payload = TournamentWizardCoordinator.buildTournamentPayload(
        name: 'Super Cup',
        type: 'Cup',
        sportType: 'Football',
        startDate: now,
        endDate: now.add(const Duration(days: 14)),
        governorate: 'Cairo',
        ownerId: 'owner_99',
        selectedTeams: '8',
        prize: '10000',
        fee: '200',
        numberOfGroups: 2,
        qualifyingPerGroup: 2,
        isTwoLegs: false,
        duration: '45',
      );

      expect(payload['name'], 'Super Cup');
      expect(payload['type'], 'Cup');
      expect(payload['maxTeams'], 8);
      expect(payload['grandPrize'], 10000.0);
      expect(payload['entryFee'], 200.0);
      expect(payload['settings']['matchDuration'], 45);
    });
  });
}
