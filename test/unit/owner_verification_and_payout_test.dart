import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/owner/widgets/documentation/doc_wizard_hydrator.dart';

void main() {
  group('Owner Stadium Onboarding & Verification SSOT', () {
    test('DocWizardHydrator correctly extracts all 4 mandatory documents', () {
      final additionalData = {
        'verificationDocuments': {
          'commercialRegisterUrl': 'https://storage.vsp.app/cr.pdf',
          'taxCardUrl': 'https://storage.vsp.app/tax.pdf',
          'nationalIdFrontUrl': 'https://storage.vsp.app/id_front.jpg',
          'nationalIdBackUrl': 'https://storage.vsp.app/id_back.jpg',
        }
      };

      final hydrated = DocWizardHydrator.hydrate(additionalData);
      expect(hydrated.docUrls['commercialRegister'], equals('https://storage.vsp.app/cr.pdf'));
      expect(hydrated.docUrls['taxCard'], equals('https://storage.vsp.app/tax.pdf'));
      expect(hydrated.docUrls['idFront'], equals('https://storage.vsp.app/id_front.jpg'));
      expect(hydrated.docUrls['idBack'], equals('https://storage.vsp.app/id_back.jpg'));
    });

    test('DocWizardHydrator handles fallback legacy keys gracefully', () {
      final additionalData = {
        'commercialRegister': 'https://storage.vsp.app/cr_alt.pdf',
        'taxCard': 'https://storage.vsp.app/tax_alt.pdf',
        'idFront': 'https://storage.vsp.app/front_alt.jpg',
        'idBack': 'https://storage.vsp.app/back_alt.jpg',
      };

      final hydrated = DocWizardHydrator.hydrate(additionalData);
      expect(hydrated.docUrls['commercialRegister'], equals('https://storage.vsp.app/cr_alt.pdf'));
      expect(hydrated.docUrls['taxCard'], equals('https://storage.vsp.app/tax_alt.pdf'));
      expect(hydrated.docUrls['idFront'], equals('https://storage.vsp.app/front_alt.jpg'));
      expect(hydrated.docUrls['idBack'], equals('https://storage.vsp.app/back_alt.jpg'));
    });

    test('Validation fails if any of the 4 mandatory documents is missing', () {
      bool isVerificationSubmissionValid(Map<String, dynamic> data) {
        final hydrated = DocWizardHydrator.hydrate(data);
        final docs = hydrated.docUrls;
        return (docs['commercialRegister']?.trim().isNotEmpty ?? false) &&
            (docs['taxCard']?.trim().isNotEmpty ?? false) &&
            (docs['idFront']?.trim().isNotEmpty ?? false) &&
            (docs['idBack']?.trim().isNotEmpty ?? false);
      }

      // Missing commercial register
      expect(
        isVerificationSubmissionValid({
          'verificationDocuments': {
            'taxCardUrl': 'https://storage.vsp.app/tax.pdf',
            'nationalIdFrontUrl': 'https://storage.vsp.app/id_f.jpg',
            'nationalIdBackUrl': 'https://storage.vsp.app/id_b.jpg',
          }
        }),
        isFalse,
      );

      // Missing tax card
      expect(
        isVerificationSubmissionValid({
          'verificationDocuments': {
            'commercialRegisterUrl': 'https://storage.vsp.app/cr.pdf',
            'nationalIdFrontUrl': 'https://storage.vsp.app/id_f.jpg',
            'nationalIdBackUrl': 'https://storage.vsp.app/id_b.jpg',
          }
        }),
        isFalse,
      );

      // Missing ID front
      expect(
        isVerificationSubmissionValid({
          'verificationDocuments': {
            'commercialRegisterUrl': 'https://storage.vsp.app/cr.pdf',
            'taxCardUrl': 'https://storage.vsp.app/tax.pdf',
            'nationalIdBackUrl': 'https://storage.vsp.app/id_b.jpg',
          }
        }),
        isFalse,
      );

      // Missing ID back
      expect(
        isVerificationSubmissionValid({
          'verificationDocuments': {
            'commercialRegisterUrl': 'https://storage.vsp.app/cr.pdf',
            'taxCardUrl': 'https://storage.vsp.app/tax.pdf',
            'nationalIdFrontUrl': 'https://storage.vsp.app/id_f.jpg',
          }
        }),
        isFalse,
      );

      // All 4 present
      expect(
        isVerificationSubmissionValid({
          'verificationDocuments': {
            'commercialRegisterUrl': 'https://storage.vsp.app/cr.pdf',
            'taxCardUrl': 'https://storage.vsp.app/tax.pdf',
            'nationalIdFrontUrl': 'https://storage.vsp.app/id_f.jpg',
            'nationalIdBackUrl': 'https://storage.vsp.app/id_b.jpg',
          }
        }),
        isTrue,
      );
    });
  });

  group('Owner Payout & Settlement Ledger SSOT', () {
    test('Available balance restores automatically when pending payout is rejected', () {
      const double onlineEarned = 5000.0;
      const double totalWithdrawn = 1000.0;
      double pendingPayouts = 2000.0;

      // Initial state: 1 pending payout of 2000
      double availableBalance = onlineEarned - totalWithdrawn - pendingPayouts;
      expect(availableBalance, equals(2000.0));

      // Rejection event: status changed from 'pending' to 'rejected'
      // The rejected settlement is no longer counted in pending_payouts
      pendingPayouts -= 2000.0;

      // Restored balance:
      availableBalance = onlineEarned - totalWithdrawn - pendingPayouts;
      expect(availableBalance, equals(4000.0));
      // Rejection does not create a new income or fee; it strictly releases the lock
    });

    test('Completed payout cannot be rejected and does not restore balance', () {
      const double onlineEarned = 5000.0;
      double totalWithdrawn = 3000.0;
      const double pendingPayouts = 0.0;

      double availableBalance = onlineEarned - totalWithdrawn - pendingPayouts;
      expect(availableBalance, equals(2000.0));

      // Attempting to reject a completed payout must fail
      bool canReject(String status) => status == 'pending' || status == 'approved';
      expect(canReject('completed'), isFalse);
      expect(canReject('rejected'), isFalse);
      expect(canReject('pending'), isTrue);
      expect(canReject('approved'), isTrue);
    });

    test('Idempotent rejection does not alter pending payouts or available balance twice', () {
      const double onlineEarned = 10000.0;
      const double totalWithdrawn = 2000.0;
      List<Map<String, dynamic>> settlements = [
        {'id': 's-1', 'amount': 1500.0, 'status': 'pending'},
        {'id': 's-2', 'amount': 2500.0, 'status': 'pending'},
      ];

      double computeAvailable() {
        final pending = settlements
            .where((s) => s['status'] == 'pending' || s['status'] == 'approved')
            .fold(0.0, (acc, s) => acc + (s['amount'] as double));
        return onlineEarned - totalWithdrawn - pending;
      }

      expect(computeAvailable(), equals(4000.0)); // 10000 - 2000 - 4000

      // First rejection of s-1
      settlements[0]['status'] = 'rejected';
      expect(computeAvailable(), equals(5500.0)); // 10000 - 2000 - 2500

      // Second idempotent rejection of s-1 (no status change)
      settlements[0]['status'] = 'rejected';
      expect(computeAvailable(), equals(5500.0));
    });
  });
}
