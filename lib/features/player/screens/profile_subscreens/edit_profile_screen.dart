import 'dart:io';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../../core/ui/vsp_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/image_pick_service.dart';
import '../../../../core/services/storage_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/vsp_back_button.dart';
import '../../../../shared/dialogs/account_deletion_dialog.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../../auth/screens/welcome_screen.dart';

class EditProfileScreen extends StatefulWidget {
 const EditProfileScreen({super.key});

 @override
 State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
 late TextEditingController _nameController;
 late TextEditingController _phoneController;
 String? _selectedPosition;
 String _selectedSport = 'Football';
 bool _isLoading = false;
 bool _isDeletionDialogOpen = false;
 XFile? _newProfileImage;

 @override
 void initState() {
 super.initState();
 final user = Provider.of<AuthProvider>(context, listen: false).userModel;
 _nameController = TextEditingController(text: user?.name ?? '');
 _phoneController = TextEditingController(text: user?.phone ?? '');
 _selectedSport = user?.favoriteSport ?? 'Football';
 _selectedPosition = user?.position;
 }

 @override
 void dispose() {
 _nameController.dispose();
 _phoneController.dispose();
 super.dispose();
 }

 Future<void> _pickImage() async {
 if (_isLoading) return;
 final image = await ImagePickService.pick(
 context,
 aspectRatio: CropAspectRatioPreset.square,
 );
 if (image != null && mounted) {
 setState(() => _newProfileImage = image);
 }
 }

 Future<void> _saveChanges() async {
 // Validation
 final name = _nameController.text.trim();
 final normalizedPhone = PhoneUtils.normalize(_phoneController.text.trim());
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';

 if (name.length < 2 || name.length > 80) {
 VSPFeedback.showError(context, AppLocalizations.of(context)!.nameEmptyError);
 return;
 }
 if (normalizedPhone == null ||
     normalizedPhone.length != 11 ||
     !normalizedPhone.startsWith('01')) {
 VSPFeedback.showError(
 context,
 isArabic ? 'اكتب رقم موبايل مصري صحيح.' : 'Enter a valid Egyptian mobile number.',
 );
 return;
 }

 final auth = Provider.of<AuthProvider>(context, listen: false);
 final submittingUserId = auth.userModel?.uid ?? auth.currentUser?.id;
 if (submittingUserId == null || submittingUserId.isEmpty) {
 VSPFeedback.showError(
 context,
 isArabic ? 'انتهت جلسة تسجيل الدخول. سجّل الدخول مرة أخرى.' : 'Your session ended. Please sign in again.',
 );
 return;
 }
 if (auth.isPlayer) {
 final validPositions = SportPositionsRegistry.getPositionsForSport(_selectedSport)
     .map((position) => position.code)
     .toSet();
 if (_selectedPosition == null || !validPositions.contains(_selectedPosition)) {
 VSPFeedback.showError(
 context,
 isArabic ? 'اختار مركز لعب صحيح قبل الحفظ.' : 'Choose a valid playing position before saving.',
 );
 return;
 }
 }

 setState(() => _isLoading = true);

 try {
 // Save the text fields first. If the subsequent optional image upload fails,
 // keep the selected image for an explicit retry and report the partial save.
 final Map<String, dynamic> updateData = {
 'name': name,
 'phone': normalizedPhone,
 };
 if (auth.isPlayer && _selectedPosition != null) {
 updateData['position'] = _selectedPosition;
 }

 final success = await auth.updateProfile(updateData);
 if (!mounted ||
     (auth.userModel?.uid ?? auth.currentUser?.id) != submittingUserId) {
 return;
 }
 if (!success) {
 VSPFeedback.showError(context, AppLocalizations.of(context)!.profileUpdateFailed);
 return;
 }

 if (_newProfileImage != null) {
 final compressed = await StorageService().compressImage(_newProfileImage!);
 final photoSaved = await auth.updateProfilePhoto(compressed ?? _newProfileImage!);
 if (!mounted ||
     (auth.userModel?.uid ?? auth.currentUser?.id) != submittingUserId) {
 return;
 }
 if (!photoSaved) {
 VSPFeedback.showError(
 context,
 isArabic
     ? 'تم حفظ بياناتك، لكن تعذر رفع الصورة. جرّب رفع الصورة مرة أخرى.'
     : 'Your details were saved, but the photo upload failed. Try the photo again.',
 );
 return;
 }
 }

 VSPFeedback.showSuccess(context, AppLocalizations.of(context)!.profileUpdatedSuccess);
 Navigator.pop(context); // Go back to profile screen
 } catch (e) {
 if (mounted) {
 VSPFeedback.showError(context, AppLocalizations.of(context)!.profileUpdateFailed);
 }
 } finally {
 if (mounted) setState(() => _isLoading = false);
 }
 }

 @override
 Widget build(BuildContext context) {
 final userProfileUrl = Provider.of<AuthProvider>(context).userModel?.profileImageUrl;

 return VSPScaffold(
 backgroundColor: VSPColors.background,
 appBar: AppBar(
 backgroundColor: VSPColors.transparent,
 elevation: 0,
 leading: const VSPBackButton(),
 title: Text(
 AppLocalizations.of(context)!.editProfile,
 style: Theme.of(context).textTheme.displaySmall,
 ),
 centerTitle: true,
 ),
 body: SafeArea(top: false, bottom: false,
 child: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
 padding: EdgeInsets.only(
 left: VSPSpacing.lg,
 right: VSPSpacing.lg,
 top: VSPSpacing.lg,
 bottom: MediaQuery.of(context).viewInsets.bottom > 0
 ? MediaQuery.of(context).viewInsets.bottom + VSPSpacing.lg
 : (MediaQuery.of(context).padding.bottom > 0
 ? MediaQuery.of(context).padding.bottom + VSPSpacing.lg
 : VSPSpacing.lg),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 // --- Profile Picture Section ---
 GestureDetector(
 onTap: _pickImage,
 child: Stack(
 alignment: AlignmentDirectional.bottomEnd,
 children: [
 Container(
 width: 100,
 height: 100,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 border: Border.all(color: VSPColors.accent, width: 2),
 color: VSPColors.surface,
 ),
 child: ClipOval(
 child: _newProfileImage != null
 ? Image.file(File(_newProfileImage!.path), fit: BoxFit.cover)
 : (userProfileUrl != null && userProfileUrl.isNotEmpty)
 ? CachedNetworkImage(
 imageUrl: userProfileUrl,
 memCacheWidth: 250,
 memCacheHeight: 250,
 fit: BoxFit.cover,
 placeholder: (context, url) => const CircularProgressIndicator(color: VSPColors.accent),
 errorWidget: (context, url, error) => const Icon(Iconsax.user_copy, size: 50, color: VSPColors.textSecondary),
 )
 : const Icon(Iconsax.user_copy, size: 50, color: VSPColors.textSecondary),
 ),
 ),
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: VSPColors.accent,
 shape: BoxShape.circle,
 border: Border.all(color: VSPColors.background, width: 3),
 ),
 child: const Icon(Iconsax.image_copy, size: 16, color: VSPColors.black),
 ),
 ],
 ),
 ),
 const SizedBox(height: VSPSpacing.xxl),

 // --- Form Fields ---
 Align(
 alignment: AlignmentDirectional.centerStart,
 child: Text(AppLocalizations.of(context)!.fullName, style: Theme.of(context).textTheme.labelMedium),
 ),
 const SizedBox(height: VSPSpacing.xs),
 CustomTextField(
 controller: _nameController,
 hintText: AppLocalizations.of(context)!.enterName,
 prefixIcon: Iconsax.user_copy,
 ),

 const SizedBox(height: VSPSpacing.md),

 Align(
 alignment: AlignmentDirectional.centerStart,
 child: Text(AppLocalizations.of(context)!.phoneNumber, style: Theme.of(context).textTheme.labelMedium),
 ),
 const SizedBox(height: VSPSpacing.xs),
 CustomTextField(
 controller: _phoneController,
 hintText: AppLocalizations.of(context)!.enterPhone,
 keyboardType: TextInputType.phone,
 prefixIcon: Iconsax.call_copy,
 ),

 if (Provider.of<AuthProvider>(context).isPlayer) ...[
 const SizedBox(height: VSPSpacing.md),

 Align(
 alignment: AlignmentDirectional.centerStart,
 child: Text(AppLocalizations.of(context)!.preferredPosition, style: Theme.of(context).textTheme.labelMedium),
 ),
 const SizedBox(height: VSPSpacing.xs),
 
 // Position Dropdown
 Builder(
 builder: (context) {
 final isAr = Localizations.localeOf(context).languageCode == 'ar';
 final availablePositions = SportPositionsRegistry.getPositionsForSport(_selectedSport);
 final validPositionCodes = availablePositions.map((p) => p.code).toList();
 final selectedVal = (validPositionCodes.contains(_selectedPosition)) ? _selectedPosition : null;

 return Container(
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: selectedVal,
 hint: Text(AppLocalizations.of(context)!.preferredPosition, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary)),
 dropdownColor: VSPColors.surface,
 icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.textSecondary),
 isExpanded: true,
 style: Theme.of(context).textTheme.bodyMedium,
 items: availablePositions.map((pos) {
 final label = isAr ? '${pos.code} - ${pos.nameAr}' : '${pos.code} - ${pos.nameEn}';
 return DropdownMenuItem<String>(
 value: pos.code,
 child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.white)),
 );
 }).toList(),
 onChanged: (String? newValue) {
 if (newValue != null) {
 HapticFeedback.selectionClick();
 setState(() {
 _selectedPosition = newValue;
 });
 }
 },
 ),
 ),
 );
 },
 ),
 ],

 const SizedBox(height: 24),

 // --- Save Button ---
 PrimaryButton(
 text: AppLocalizations.of(context)!.saveChanges,
 isLoading: _isLoading,
 onPressed: _isLoading ? null : _saveChanges,
 ),

 const SizedBox(height: VSPSpacing.md),

 // --- Delete Account Danger Zone Card ---
 Builder(
 builder: (context) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 return Container(
 width: double.infinity,
 margin: const EdgeInsets.only(top: VSPSpacing.md),
 padding: const EdgeInsets.all(VSPSpacing.md),
 decoration: BoxDecoration(
 color: VSPColors.error.withValues(alpha: 0.08),
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 border: Border.all(color: VSPColors.error.withValues(alpha: 0.3), width: 1.5),
 ),
 child: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: VSPColors.error.withValues(alpha: 0.15),
 shape: BoxShape.circle,
 ),
 child: const Icon(Iconsax.user_remove_copy, color: VSPColors.error, size: 22),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 isArabic ? 'حذف الحساب نهائياً' : 'Delete Account',
 style: const TextStyle(
 color: VSPColors.error,
 fontWeight: FontWeight.bold,
 fontSize: 15,
 ),
 ),
 const SizedBox(height: 2),
 Text(
 isArabic ? 'حذف الحساب والبيانات المرتبطة به' : 'Delete your account and associated data',
 style: TextStyle(
 color: VSPColors.textSecondary.withValues(alpha: 0.8),
 fontSize: 11,
 ),
 ),
 ],
 ),
 ),
 TextButton(
 onPressed: _isDeletionDialogOpen ? null : () => _showDeleteAccountDialog(context),
 style: TextButton.styleFrom(
 backgroundColor: VSPColors.error,
 foregroundColor: VSPColors.white,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
 ),
 child: Text(
 isArabic ? 'حذف' : 'Delete',
 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
 ),
 ),
 ],
 ),
 );
 }
 ),
 ],
 ),
 ),
 ),
 );
 }

 Future<void> _showDeleteAccountDialog(BuildContext context) async {
   if (_isDeletionDialogOpen) return;
   final auth = context.read<AuthProvider>();
   final uid = auth.currentUser?.id;
   if (uid == null) return;
   setState(() => _isDeletionDialogOpen = true);
   try {
     final deleted = await showAccountDeletionDialog(
       context,
       onDelete: (_) async {
         if (auth.currentUser?.id != uid) return false;
         return auth.deleteAccount();
       },
     );
     if (deleted == true && context.mounted) {
       Navigator.of(context).pushAndRemoveUntil(
         MaterialPageRoute(builder: (_) => const WelcomeScreen()),
         (route) => false,
       );
     }
   } finally {
     if (mounted) setState(() => _isDeletionDialogOpen = false);
   }
 }
}
