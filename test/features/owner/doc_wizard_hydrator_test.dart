import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/owner/widgets/documentation/doc_wizard_hydrator.dart';

void main() {
  group('DocWizardHydrator Tests', () {
    test('hydrate returns step 0 and null URLs for null or empty input', () {
      final res1 = DocWizardHydrator.hydrate(null);
      expect(res1.initialStep, 0);
      expect(res1.docUrls['commercialRegister'], isNull);
      expect(res1.docUrls['taxCard'], isNull);
      expect(res1.docUrls['idFront'], isNull);
      expect(res1.docUrls['idBack'], isNull);

      final res2 = DocWizardHydrator.hydrate({});
      expect(res2.initialStep, 0);
    });

    test('hydrate parses flat and nested verificationDocuments and advances step', () {
      final data = {
        'verificationDocuments': {
          'commercialRegister': 'https://vsp.com/cr.pdf',
          'taxCard': 'https://vsp.com/tc.pdf',
        },
      };

      final res = DocWizardHydrator.hydrate(data);
      expect(res.docUrls['commercialRegister'], 'https://vsp.com/cr.pdf');
      expect(res.docUrls['taxCard'], 'https://vsp.com/tc.pdf');
      expect(res.docUrls['idFront'], isNull);
      // Because commercialRegister and taxCard are present, but not IDs -> step 2
      expect(res.initialStep, 2);
    });

    test('hydrate parses single commercial register and sets step 1', () {
      final data = {
        'commercialRegisterUrl': 'https://vsp.com/cr.jpg',
      };

      final res = DocWizardHydrator.hydrate(data);
      expect(res.docUrls['commercialRegister'], 'https://vsp.com/cr.jpg');
      expect(res.docUrls['taxCard'], isNull);
      expect(res.initialStep, 1);
    });
  });
}
