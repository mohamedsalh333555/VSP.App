import 'dart:io';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/image_pick_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../shared/widgets/vsp_upload_widgets.dart';
import '../../../core/services/owner_document_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/vsp_feedback.dart';

class OwnerDocumentationWizard extends StatefulWidget {
 const OwnerDocumentationWizard({super.key});

 @override
 State<OwnerDocumentationWizard> createState() => _OwnerDocumentationWizardState();
}

class _OwnerDocumentationWizardState extends State<OwnerDocumentationWizard> {
 final PageController _pageController = PageController();
 int _currentStep = 0;
 bool _isSaving = false; // blocks the Save button during profile update

 final OwnerDocumentService _documentService = OwnerDocumentService();

 // Document upload state
 final Map<String, String?> _uploadedDocUrls = {
 'commercialRegister': null,
 'taxCard': null,
 'idFront': null,
 'idBack': null,
 };
 final Map<String, bool> _uploadingStatus = {
 'commercialRegister': false,
 'taxCard': false,
 'idFront': false,
 'idBack': false,
 };

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) {
 _hydrateExistingDocuments();
 });
 }

 void _hydrateExistingDocuments() {
 final auth = Provider.of<AuthProvider>(context, listen: false);
 final user = auth.userModel;
 if (user == null) return;

 final addData = user.additionalData ?? {};
 final docs = (addData['verificationDocuments'] is Map)
 ? (addData['verificationDocuments'] as Map<dynamic, dynamic>)
 : addData;

 final String? cr = (docs['commercialRegister'] ?? docs['commercialRegisterUrl'] ?? addData['commercialRegister'] ?? addData['commercialRegisterUrl'] ?? addData['contractUrl'])?.toString();
 final String? tc = (docs['taxCard'] ?? docs['taxCardUrl'] ?? addData['taxCard'] ?? addData['taxCardUrl'])?.toString();
 final String? idF = (docs['idFront'] ?? docs['nationalIdFrontUrl'] ?? docs['idFrontUrl'] ?? addData['idFront'] ?? addData['nationalIdFrontUrl'] ?? addData['ownerIdUrl'])?.toString();
 final String? idB = (docs['idBack'] ?? docs['nationalIdBackUrl'] ?? docs['idBackUrl'] ?? addData['idBack'] ?? addData['nationalIdBackUrl'])?.toString();

 setState(() {
 if (cr != null && cr.isNotEmpty) _uploadedDocUrls['commercialRegister'] = cr;
 if (tc != null && tc.isNotEmpty) _uploadedDocUrls['taxCard'] = tc;
 if (idF != null && idF.isNotEmpty) _uploadedDocUrls['idFront'] = idF;
 if (idB != null && idB.isNotEmpty) _uploadedDocUrls['idBack'] = idB;

 // Smart Step Auto-Advance:
 if (_uploadedDocUrls['commercialRegister'] != null && _uploadedDocUrls['taxCard'] == null) {
 _currentStep = 1;
 } else if (_uploadedDocUrls['commercialRegister'] != null &&
 _uploadedDocUrls['taxCard'] != null &&
 (_uploadedDocUrls['idFront'] == null || _uploadedDocUrls['idBack'] == null)) {
 _currentStep = 2;
 }

 if (_currentStep > 0 && _pageController.hasClients) {
 _pageController.jumpToPage(_currentStep);
 }
 });
 }

 @override
 void dispose() {
 _pageController.dispose();
 super.dispose();
 }

 // ignore: unused_field
 final ImagePicker _picker = ImagePicker();

 Future<void> _showImageSourceActionSheet(OwnerDocumentType type, String key) async {
 showModalBottomSheet(
 context: context,
 backgroundColor: VSPColors.background,
 shape: const RoundedRectangleBorder(
 borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
 ),
 builder: (context) => SafeArea(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 const SizedBox(height: VSPSpacing.md),
 Text(
 AppLocalizations.of(context)!.selectImageSource,
 style: Theme.of(context).textTheme.displaySmall,
 ),
 const SizedBox(height: VSPSpacing.md),
 ListTile(
 leading: const Icon(Iconsax.image_copy, color: VSPColors.accent),
 title: Text(AppLocalizations.of(context)!.camera, style: const TextStyle(color: VSPColors.textPrimary)),
 onTap: () {
 Navigator.pop(context);
 _pickAndUpload(type, key, ImageSource.camera);
 },
 ),
 ListTile(
 leading: const Icon(Iconsax.image_copy, color: VSPColors.accent),
 title: Text(AppLocalizations.of(context)!.gallery, style: const TextStyle(color: VSPColors.textPrimary)),
 onTap: () {
 Navigator.pop(context);
 _pickAndUpload(type, key, ImageSource.gallery);
 },
 ),
 ListTile(
 leading: const Icon(Iconsax.document_text_copy, color: VSPColors.accent),
 title: const Text('الملفات (PDF / صور)', style: TextStyle(color: VSPColors.textPrimary)),
 onTap: () {
 Navigator.pop(context);
 _pickAndUploadDocumentFile(type, key);
 },
 ),
 const SizedBox(height: VSPSpacing.md),
 ],
 ),
 ),
 );
 }

 Future<void> _pickAndUploadDocumentFile(OwnerDocumentType type, String key) async {
 try {
 final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg']);
 if (result == null) return;
 final file = result.files.single;
 XFile xFile;
 if (kIsWeb) {
 if (file.bytes == null) return;
 xFile = XFile.fromData(file.bytes!, name: file.name);
 } else {
 if (file.path == null) return;
 xFile = XFile(file.path!);
 }

 setState(() {
 _uploadingStatus[key] = true;
 });

 if (!mounted) return;
 final authProvider = Provider.of<AuthProvider>(context, listen: false);
 final uid = authProvider.currentUser?.uid;
 if (uid == null) {
 setState(() => _uploadingStatus[key] = false);
 VSPFeedback.showError(context, AppLocalizations.of(context)!.sessionExpiredError);
 return;
 }

 final url = await _documentService.uploadAndSave(
 type: type,
 file: xFile,
 uid: uid,
 );

 if (!mounted) return;
 setState(() {
 _uploadedDocUrls[key] = url;
 _uploadingStatus[key] = false;
 });

 VSPFeedback.showSuccess(context, AppLocalizations.of(context)!.docUploadedSuccess);
 } catch (e) {
 if (mounted) {
 setState(() {
 _uploadingStatus[key] = false;
 });
 VSPFeedback.showError(context, AppLocalizations.of(context)!.uploadFailed(e.toString()));
 }
 }
 }

 Future<void> _pickAndUpload(OwnerDocumentType type, String key, ImageSource source) async {
 try {
 final XFile? pickedFile = await ImagePickService.pick(
 context,
 aspectRatio: CropAspectRatioPreset.original, // Documents can be any shape
 source: source,
 );
 
 if (!mounted) return;
 if (pickedFile == null) return;

 setState(() {
 _uploadingStatus[key] = true;
 });

 if (!mounted) return;
 final authProvider = Provider.of<AuthProvider>(context, listen: false);
 final uid = authProvider.currentUser?.uid;
 if (uid == null) {
 setState(() => _uploadingStatus[key] = false);
 VSPFeedback.showError(context, AppLocalizations.of(context)!.sessionExpiredError);
 return;
 }

 final url = await _documentService.uploadAndSave(
 type: type,
 file: pickedFile,
 uid: uid,
 );
 
 // Clean up temporary cached file immediately after upload
 try {
 final tempF = File(pickedFile.path);
 if (await tempF.exists()) {
 await tempF.delete();
 }
 } catch (_) {}
 
 if (!mounted) return;
 setState(() {
 _uploadedDocUrls[key] = url;
 _uploadingStatus[key] = false;
 });
 
 VSPFeedback.showSuccess(context, AppLocalizations.of(context)!.docUploadedSuccess);
 } catch (e) {
 if (mounted && context.mounted) {
 setState(() {
 _uploadingStatus[key] = false;
 });
 VSPFeedback.showError(context, AppLocalizations.of(context)!.uploadFailed(e.toString()));
 }
 }
 }

 /// Validate required uploads for the current step before advancing.
 void _nextPage() {
 if (_currentStep == 0) {
 // Step 1: commercial register is mandatory.
 if (_uploadedDocUrls['commercialRegister'] == null) {
 VSPFeedback.showError(
 context,
 AppLocalizations.of(context)!.uploadCommRegisterRequired,
 );
 return;
 }
 _pageController.nextPage(
 duration: const Duration(milliseconds: 300),
 curve: Curves.easeInOut,
 );
 setState(() => _currentStep++);
 } else if (_currentStep == 1) {
 // Step 2: tax card is mandatory.
 if (_uploadedDocUrls['taxCard'] == null) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 VSPFeedback.showError(
 context,
 isArabic ? 'يرجى رفع البطاقة الضريبية أولاً.' : 'Please upload the tax card first.',
 );
 return;
 }
 _pageController.nextPage(
 duration: const Duration(milliseconds: 300),
 curve: Curves.easeInOut,
 );
 setState(() => _currentStep++);
 } else {
 // Step 3: both ID sides are mandatory.
 if (_uploadedDocUrls['idFront'] == null) {
 VSPFeedback.showError(
 context,
 AppLocalizations.of(context)!.uploadIdFrontRequired,
 );
 return;
 }
 if (_uploadedDocUrls['idBack'] == null) {
 VSPFeedback.showError(
 context,
 AppLocalizations.of(context)!.uploadIdBackRequired,
 );
 return;
 }
 _saveDocumentsAndShowReview();
 }
 }
 
 /// Finalise onboarding: write flags, then (and ONLY then) show success and navigate.
 Future<void> _saveDocumentsAndShowReview() async {
 if (_isSaving) return; // guard against double-tap
 setState(() => _isSaving = true);

 try {
 final authProvider = Provider.of<AuthProvider>(context, listen: false);

 if (authProvider.firebaseUser == null) {
 VSPFeedback.showError(context, AppLocalizations.of(context)!.sessionExpiredError);
 setState(() => _isSaving = false);
 return;
 }

 // Submit documents: verificationStatus is strictly 'pending'
 // requiring real Admin approval from Admin Dashboard.
 final bool saved = await authProvider.completeOwnerRegistration(
 verificationStatus: 'pending',
 );

 if (!saved) {
 if (!mounted || !context.mounted) return;
 setState(() => _isSaving = false);
 VSPFeedback.showError(context, AppLocalizations.of(context)!.saveInfoFailed);
 return;
 }

 // Only reached when completeOwnerRegistration succeeds without throwing.
 if (!mounted || !context.mounted) return;
 setState(() => _isSaving = false);

 final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

 await showDialog(
 context: context,
 barrierDismissible: false,
 builder: (ctx) => AlertDialog(
 backgroundColor: VSPColors.surface,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 ),
 icon: const Icon(
 Iconsax.clock_copy,
 color: VSPColors.accent,
 size: 48,
 ),
 title: Text(
 isArabic ? ' قيد المراجعة' : ' Under Review',
 style: Theme.of(ctx).textTheme.titleLarge,
 textAlign: TextAlign.center,
 ),
 content: Text(
 isArabic
 ? "لقد تم استلام بياناتك بنجاح! \n\nنحن الآن نقوم بمراجعتها. يمكنك الانتقال لاستكشاف لوحة التحكم الخاصة بك الآن، ولكن يرجى العلم أن ملاعبك ستظل مخفية عن اللاعبين حتى يتم التوثيق من الإدارة."
 : "Your data has been successfully received! \n\nWe are reviewing it now. You can explore your dashboard, but your stadiums will remain hidden from players until verified by admin.",
 style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
 color: VSPColors.textSecondary,
 height: 1.6,
 ),
 textAlign: TextAlign.center,
 ),
 actionsPadding: const EdgeInsets.symmetric(
 horizontal: VSPSpacing.md,
 vertical: VSPSpacing.md,
 ),
 actions: [
 PrimaryButton(
 text: isArabic ? 'الذهاب إلى لوحة التحكم' : 'Go to Dashboard',
 height: 48,
 onPressed: () => Navigator.of(ctx).pop(),
 ),
 ],
 ),
 );

 // Navigate only after the dialog is dismissed.
 if (mounted && context.mounted) {
 context.go('/owner');
 }
 } catch (e) {
 if (!mounted || !context.mounted) return;
 setState(() => _isSaving = false);
 VSPFeedback.showError(
 context,
 AppLocalizations.of(context)!.saveInfoFailed,
 );
 }
 }


 void _previousPage() {
 if (_currentStep > 0) {
 _pageController.previousPage(
 duration: const Duration(milliseconds: 300),
 curve: Curves.easeInOut,
 );
 setState(() {
 _currentStep--;
 });
 } else {
 Navigator.pop(context);
 }
 }

 @override
 Widget build(BuildContext context) {
 final isUploadingAny = _uploadingStatus.values.any((s) => s == true) || _isSaving;
 return PopScope(
 canPop: !isUploadingAny,
 onPopInvokedWithResult: (didPop, result) async {
 if (didPop) return;
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 final confirm = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 backgroundColor: VSPColors.surface,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
 title: Text(
 isArabic ? 'إلغاء رفع المستندات؟' : 'Cancel Document Upload?',
 style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold),
 ),
 content: Text(
 isArabic
 ? 'جاري رفع المستندات الآن، هل أنت متأكد من رغبتك في إيقاف الرفع والخروج؟'
 : 'Documents are currently uploading. Are you sure you want to stop and exit?',
 style: const TextStyle(color: VSPColors.textSecondary),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx, false),
 child: Text(isArabic ? 'متابعة الرفع' : 'Continue Upload', style: const TextStyle(color: VSPColors.accent)),
 ),
 ElevatedButton(
 onPressed: () => Navigator.pop(ctx, true),
 style: ElevatedButton.styleFrom(backgroundColor: VSPColors.error),
 child: Text(isArabic ? 'إلغاء وخروج' : 'Cancel & Exit'),
 ),
 ],
 ),
 );
 if (confirm == true && context.mounted) {
 Navigator.pop(context);
 }
 },
 child: Scaffold(
 backgroundColor: VSPColors.background,
 appBar: AppBar(
 backgroundColor: VSPColors.background,
 elevation: 0,
 leading: VSPBackButton(onTap: _previousPage),
 title: Text(
 AppLocalizations.of(context)!.ownerInformationTitle,
 style: Theme.of(context).textTheme.displaySmall,
 ),
 centerTitle: true,
 ),
 body: SafeArea(
 child: Column(
 children: [
 const SizedBox(height: VSPSpacing.sm),
 Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 _buildDot(0),
 const SizedBox(width: VSPSpacing.xs),
 _buildDot(1),
 const SizedBox(width: VSPSpacing.xs),
 _buildDot(2),
 ],
 ),
 const SizedBox(height: VSPSpacing.md),
 Expanded(
 child: PageView(
 controller: _pageController,
 physics: const NeverScrollableScrollPhysics(),
 children: [
 _buildStep1BusinessDocs(),
 _buildStep2TaxCard(),
 _buildStep3PersonalID(),
 ],
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 Widget _buildDot(int index) {
 return Container(
 width: _currentStep == index ? 24 : 8,
 height: 4,
 decoration: BoxDecoration(
 color: _currentStep == index ? VSPColors.accent : VSPColors.divider,
 borderRadius: BorderRadius.circular(2),
 ),
 );
 }

 Widget _buildExplanationCard({
 required String title,
 required String description,
 required IconData icon,
 }) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: VSPColors.surfaceAlt.withValues(alpha: 0.6),
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.15), width: 1),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.1),
 blurRadius: 10,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(VSPRadius.md),
 ),
 child: Icon(icon, color: VSPColors.accent, size: 24),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 color: VSPColors.textPrimary,
 fontSize: 16,
 fontWeight: FontWeight.bold,
 ),
 ),
 const SizedBox(height: 6),
 Text(
 description,
 style: const TextStyle(
 color: VSPColors.textSecondary,
 fontSize: 12,
 height: 1.5,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildStep1BusinessDocs() {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 return SingleChildScrollView(
 keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
 padding: const EdgeInsets.all(VSPSpacing.md),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildExplanationCard(
 title: isArabic ? 'مرحلة 1: السجل التجاري' : 'Stage 1: Commercial Register',
 description: isArabic 
 ? 'يرجى رفع صورة واضحة أو ملف PDF للسجل التجاري الخاص بملعبك/منشأتك. تأكد من أن المستند ساري المفعول ويحتوي على اسم المالك بشكل مقروء.'
 : 'Please upload a clear photo or PDF of your commercial register. Ensure the document is valid and clearly shows the owner\'s name.',
 icon: Iconsax.document_text_copy,
 ),
 const SizedBox(height: VSPSpacing.md),
 
 VspUploadMainCard(
 title: AppLocalizations.of(context)!.clickToUploadRegister,
 isLoading: _uploadingStatus['commercialRegister'] ?? false,
 onTap: () => _showImageSourceActionSheet(OwnerDocumentType.commercialRegister, 'commercialRegister'),
 ),

 if (_uploadedDocUrls['commercialRegister'] != null) ...[
 const SizedBox(height: VSPSpacing.md),
 VspUploadedItemRow(
 title: AppLocalizations.of(context)!.commercialRegister,
 subtitle: AppLocalizations.of(context)!.uploadedSuccessfully,
 thumbnailUrl: _uploadedDocUrls['commercialRegister'],
 onDelete: () => setState(() => _uploadedDocUrls['commercialRegister'] = null),
 ),
 ],

 const SizedBox(height: VSPSpacing.xxl),
 PrimaryButton(
 text: _isSaving ? AppLocalizations.of(context)!.saving : AppLocalizations.of(context)!.saveAndContinue,
 onPressed: (_isSaving || (_uploadingStatus['commercialRegister'] ?? false))
 ? null
 : _nextPage,
 ),
 SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
 ],
 ),
 );
 }

 Widget _buildStep2TaxCard() {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 return SingleChildScrollView(
 keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
 padding: const EdgeInsets.all(VSPSpacing.md),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildExplanationCard(
 title: isArabic ? 'مرحلة 2: البطاقة الضريبية' : 'Stage 2: Tax Card',
 description: isArabic 
 ? 'يرجى رفع صورة واضحة أو ملف PDF للبطاقة الضريبية الخاصة بالمنشأة. يجب أن يظهر الرقم الضريبي بوضوح للمطابقة والتحقق.'
 : 'Please upload a clear photo or PDF of your facility\'s tax card. The tax number must be clearly visible for verification.',
 icon: Iconsax.document_text_copy,
 ),
 const SizedBox(height: VSPSpacing.md),
 
 VspUploadMainCard(
 title: isArabic ? 'انقر لرفع البطاقة الضريبية' : 'Click to upload tax card',
 isLoading: _uploadingStatus['taxCard'] ?? false,
 onTap: () => _showImageSourceActionSheet(OwnerDocumentType.taxCard, 'taxCard'),
 ),

 if (_uploadedDocUrls['taxCard'] != null) ...[
 const SizedBox(height: VSPSpacing.md),
 VspUploadedItemRow(
 title: isArabic ? 'البطاقة الضريبية' : 'Tax Card',
 subtitle: isArabic ? 'تم الرفع بنجاح' : 'Uploaded Successfully',
 thumbnailUrl: _uploadedDocUrls['taxCard'],
 onDelete: () => setState(() => _uploadedDocUrls['taxCard'] = null),
 ),
 ],

 const SizedBox(height: VSPSpacing.xxl),
 PrimaryButton(
 text: _isSaving ? AppLocalizations.of(context)!.saving : AppLocalizations.of(context)!.saveAndContinue,
 onPressed: (_isSaving || (_uploadingStatus['taxCard'] ?? false))
 ? null
 : _nextPage,
 ),
 SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
 ],
 ),
 );
 }

 Widget _buildStep3PersonalID() {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 return SingleChildScrollView(
 keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
 padding: const EdgeInsets.all(VSPSpacing.md),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildExplanationCard(
 title: isArabic ? 'مرحلة 3: بطاقة الرقم القومي' : 'Stage 3: National ID',
 description: isArabic 
 ? 'يرجى رفع صورتين واضحتين للوجهين الأمامي والخلفي لبطاقة الرقم القومي الخاصة بمالك المنشأة لإتمام عملية التحقق من الهوية.'
 : 'Please upload clear photos of both the front and back of the owner\'s National ID to complete the verification process.',
 icon: Iconsax.user_copy,
 ),
 const SizedBox(height: VSPSpacing.md),
 
 VspUploadMainCard(
 title: AppLocalizations.of(context)!.nationalIdFront,
 isLoading: _uploadingStatus['idFront'] ?? false,
 onTap: () => _showImageSourceActionSheet(OwnerDocumentType.nationalIdFront, 'idFront'),
 ),

 if (_uploadedDocUrls['idFront'] != null) ...[
 const SizedBox(height: VSPSpacing.md),
 VspUploadedItemRow(
 title: AppLocalizations.of(context)!.nationalIdFront,
 subtitle: AppLocalizations.of(context)!.uploadedSuccessfully,
 thumbnailUrl: _uploadedDocUrls['idFront'],
 onDelete: () => setState(() => _uploadedDocUrls['idFront'] = null),
 ),
 ],
 
 const SizedBox(height: VSPSpacing.md),
 
 VspUploadMainCard(
 title: AppLocalizations.of(context)!.nationalIdBack,
 isLoading: _uploadingStatus['idBack'] ?? false,
 onTap: () => _showImageSourceActionSheet(OwnerDocumentType.nationalIdBack, 'idBack'),
 ),

 if (_uploadedDocUrls['idBack'] != null) ...[
 const SizedBox(height: VSPSpacing.md),
 VspUploadedItemRow(
 title: AppLocalizations.of(context)!.nationalIdBack,
 subtitle: AppLocalizations.of(context)!.uploadedSuccessfully,
 thumbnailUrl: _uploadedDocUrls['idBack'],
 onDelete: () => setState(() => _uploadedDocUrls['idBack'] = null),
 ),
 ],

 const SizedBox(height: VSPSpacing.xl),
 PrimaryButton(
 text: _isSaving ? AppLocalizations.of(context)!.saving : AppLocalizations.of(context)!.submitDocuments,
 onPressed: (_isSaving ||
 (_uploadingStatus['idFront'] ?? false) ||
 (_uploadingStatus['idBack'] ?? false))
 ? null
 : _nextPage,
 ),
 SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
 ],
 ),
 );
 }
}
