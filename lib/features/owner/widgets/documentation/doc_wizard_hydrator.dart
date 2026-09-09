/// Extracts and normalizes existing owner verification document URLs and determines the resume step.
class DocWizardHydrator {
  const DocWizardHydrator._();

  /// Hydrates initial uploaded document URLs and calculates the resume step.
  static ({Map<String, String?> docUrls, int initialStep}) hydrate(Map<String, dynamic>? additionalData) {
    final Map<String, String?> docUrls = {
      'commercialRegister': null,
      'taxCard': null,
      'idFront': null,
      'idBack': null,
    };

    if (additionalData == null || additionalData.isEmpty) {
      return (docUrls: docUrls, initialStep: 0);
    }

    final docs = (additionalData['verificationDocuments'] is Map)
        ? (additionalData['verificationDocuments'] as Map<dynamic, dynamic>)
        : additionalData;

    final String? cr = (docs['commercialRegister'] ??
            docs['commercialRegisterUrl'] ??
            additionalData['commercialRegister'] ??
            additionalData['commercialRegisterUrl'] ??
            additionalData['contractUrl'])
        ?.toString();

    final String? tc = (docs['taxCard'] ??
            docs['taxCardUrl'] ??
            additionalData['taxCard'] ??
            additionalData['taxCardUrl'])
        ?.toString();

    final String? idF = (docs['idFront'] ??
            docs['nationalIdFrontUrl'] ??
            docs['idFrontUrl'] ??
            additionalData['idFront'] ??
            additionalData['nationalIdFrontUrl'] ??
            additionalData['ownerIdUrl'])
        ?.toString();

    final String? idB = (docs['idBack'] ??
            docs['nationalIdBackUrl'] ??
            docs['idBackUrl'] ??
            additionalData['idBack'] ??
            additionalData['nationalIdBackUrl'])
        ?.toString();

    if (cr != null && cr.isNotEmpty) docUrls['commercialRegister'] = cr;
    if (tc != null && tc.isNotEmpty) docUrls['taxCard'] = tc;
    if (idF != null && idF.isNotEmpty) docUrls['idFront'] = idF;
    if (idB != null && idB.isNotEmpty) docUrls['idBack'] = idB;

    int step = 0;
    if (docUrls['commercialRegister'] != null && docUrls['taxCard'] == null) {
      step = 1;
    } else if (docUrls['commercialRegister'] != null &&
        docUrls['taxCard'] != null &&
        (docUrls['idFront'] == null || docUrls['idBack'] == null)) {
      step = 2;
    }

    return (docUrls: docUrls, initialStep: step);
  }
}
