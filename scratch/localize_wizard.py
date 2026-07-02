import re

filepath = 'lib/features/owner/screens/owner_documentation_wizard.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

replacements = [
    # Image source sheet
    ("const Text('Camera', style: TextStyle(color: VSPColors.textPrimary))", "Text(AppLocalizations.of(context)!.camera, style: const TextStyle(color: VSPColors.textPrimary))"),
    ("const Text('Gallery', style: TextStyle(color: VSPColors.textPrimary))", "Text(AppLocalizations.of(context)!.gallery, style: const TextStyle(color: VSPColors.textPrimary))"),
    ("const SizedBox(height: VSPSpacing.md),\n            Text(\n              'Select Image Source',\n              style: Theme.of(context).textTheme.displaySmall,\n            ),", "const SizedBox(height: VSPSpacing.md),\n            Text(\n              AppLocalizations.of(context)!.selectImageSource,\n              style: Theme.of(context).textTheme.displaySmall,\n            ),"),
    
    # Session / upload statuses
    ("VSPFeedback.showError(context, 'Session expired. Please sign in again.');", "VSPFeedback.showError(context, AppLocalizations.of(context)!.sessionExpiredError);"),
    ("VSPFeedback.showSuccess(context, 'Document uploaded successfully!');", "VSPFeedback.showSuccess(context, AppLocalizations.of(context)!.docUploadedSuccess);"),
    ("VSPFeedback.showError(context, 'Upload failed: $e');", "VSPFeedback.showError(context, AppLocalizations.of(context)!.uploadFailed(e.toString()));"),
    
    # Page step warnings
    ("VSPFeedback.showError(\n          context,\n          'Please upload your Commercial Register before continuing.',\n        );", "VSPFeedback.showError(\n          context,\n          AppLocalizations.of(context)!.uploadCommRegisterRequired,\n        );"),
    ("VSPFeedback.showError(\n          context,\n          'Please upload the front side of your National ID.',\n        );", "VSPFeedback.showError(\n          context,\n          AppLocalizations.of(context)!.uploadIdFrontRequired,\n        );"),
    ("VSPFeedback.showError(\n          context,\n          'Please upload the back side of your National ID.',\n        );", "VSPFeedback.showError(\n          context,\n          AppLocalizations.of(context)!.uploadIdBackRequired,\n        );"),
    
    # Complete dialog & save
    ("'Registration Complete! 🎉'", "AppLocalizations.of(context)!.regCompleteTitle"),
    ("'Your documents have been submitted for review. You can now access your dashboard and manage your stadiums.'", "AppLocalizations.of(context)!.regCompleteBody"),
    ("text: 'Go to Dashboard',", "text: AppLocalizations.of(context)!.goToDashboard,"),
    ("'Failed to save your information. Please check your connection and try again.'", "AppLocalizations.of(context)!.saveInfoFailed"),
    
    # Pending screen
    ("'Verification Pending'", "AppLocalizations.of(context)!.verificationPending"),
    ("'We are reviewing your submitted documents.'", "AppLocalizations.of(context)!.reviewingDocs"),
    ("'Submission Status'", "AppLocalizations.of(context)!.submissionStatus"),
    ("_buildStatusRow('Commercial Register', true)", "_buildStatusRow(AppLocalizations.of(context)!.commercialRegister, true)"),
    ("_buildStatusRow('National ID Front', true)", "_buildStatusRow(AppLocalizations.of(context)!.nationalIdFront, true)"),
    ("_buildStatusRow('National ID Back', true)", "_buildStatusRow(AppLocalizations.of(context)!.nationalIdBack, true)"),
    ("'The review process typically takes up to 24 hours. We will notify you once your account has been verified and activated.'", "AppLocalizations.of(context)!.reviewDurationText"),
    ("text: 'Refresh Status',", "text: AppLocalizations.of(context)!.refreshStatus,"),
    ("VSPFeedback.showSuccess(context, 'Account verified successfully!');", "VSPFeedback.showSuccess(context, AppLocalizations.of(context)!.verifiedSuccess);"),
    ("VSPFeedback.showSuccess(context, 'Documents are still under review.');", "VSPFeedback.showSuccess(context, AppLocalizations.of(context)!.stillUnderReview);"),
    ("VSPFeedback.showError(context, 'Failed to refresh status: $e');", "VSPFeedback.showError(context, AppLocalizations.of(context)!.refreshStatusFailed(e.toString()));"),
    ("child: const Text(\n                  'Sign Out',", "child: Text(\n                  AppLocalizations.of(context)!.logout,"),
    ("isSubmitted ? 'Submitted' : 'Pending'", "isSubmitted ? AppLocalizations.of(context)!.submitted : AppLocalizations.of(context)!.pending"),
    
    # Main builder
    ("'Owner information'", "AppLocalizations.of(context)!.ownerInformationTitle"),
    ("const VSPSectionTitle('Upload documents'),", "VSPSectionTitle(AppLocalizations.of(context)!.uploadDocuments),"),
    ("title: 'Click to upload commercial register',", "title: AppLocalizations.of(context)!.clickToUploadRegister,"),
    ("title: 'Commercial Register',", "title: AppLocalizations.of(context)!.commercialRegister,"),
    ("subtitle: 'Uploaded Successfully',", "subtitle: AppLocalizations.of(context)!.uploadedSuccessfully,"),
    ("text: _isSaving ? 'Saving...' : 'Save & Continue',", "text: _isSaving ? AppLocalizations.of(context)!.saving : AppLocalizations.of(context)!.saveAndContinue,"),
    ("const VSPSectionTitle('Upload national ID'),", "VSPSectionTitle(AppLocalizations.of(context)!.uploadNationalIdTitle),"),
    ("title: 'National ID Front',", "title: AppLocalizations.of(context)!.nationalIdFront,"),
    ("title: 'ID Front',", "title: AppLocalizations.of(context)!.nationalIdFront,"),
    ("title: 'National ID Back',", "title: AppLocalizations.of(context)!.nationalIdBack,"),
    ("title: 'ID Back',", "title: AppLocalizations.of(context)!.nationalIdBack,"),
    ("text: _isSaving ? 'Saving...' : 'Submit Documents',", "text: _isSaving ? AppLocalizations.of(context)!.saving : AppLocalizations.of(context)!.submitDocuments,")
]

for target, replacement in replacements:
    if target in content:
        content = content.replace(target, replacement)
    else:
        print(f"Warning: target not found:\n{target[:50]}...")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Replacement complete successfully!")
