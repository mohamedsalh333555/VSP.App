import 'dart:io';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/image_pick_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/vsp_back_button.dart';
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
 bool _isDeleting = false;
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
 final phone = _phoneController.text.trim();

 if (name.isEmpty) {
 VSPFeedback.showError(context, AppLocalizations.of(context)!.nameEmptyError);
 return;
 }

 setState(() => _isLoading = true);

 final auth = Provider.of<AuthProvider>(context, listen: false);

 try {
 // 1. Upload new image if selected
 if (_newProfileImage != null) {
 await auth.updateProfilePhoto(_newProfileImage!);
 // AuthProvider already handles the Firestore update for the photo
 }

 // 2. Update other profile data
 final Map<String, dynamic> updateData = {
 'name': name,
 'phone': PhoneUtils.normalize(phone),
 };
 if (auth.isPlayer && _selectedPosition != null) {
 updateData['position'] = _selectedPosition;
 }

 final success = await auth.updateProfile(updateData);

 if (mounted) {
 setState(() => _isLoading = false);
 if (success) {
 VSPFeedback.showSuccess(context, AppLocalizations.of(context)!.profileUpdatedSuccess);
 Navigator.pop(context); // Go back to profile screen
 } else {
 VSPFeedback.showError(context, AppLocalizations.of(context)!.profileUpdateFailed);
 }
 }
 } catch (e) {
 if (mounted) {
 setState(() => _isLoading = false);
 VSPFeedback.showError(context, AppLocalizations.of(context)!.errorOccurred(e.toString()));
 }
 }
 }

 @override
 Widget build(BuildContext context) {
 final userProfileUrl = Provider.of<AuthProvider>(context).userModel?.profileImageUrl;

 return Scaffold(
 backgroundColor: VSPColors.background,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 leading: const VSPBackButton(),
 title: Text(
 AppLocalizations.of(context)!.editProfile,
 style: Theme.of(context).textTheme.displaySmall,
 ),
 centerTitle: true,
 ),
 body: SafeArea(
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
 alignment: Alignment.bottomRight,
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
 child: const Icon(Iconsax.image_copy, size: 16, color: Colors.black),
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
 child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
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
 isArabic ? 'حذف كافة البيانات والحجوزات نهائياً' : 'Permanently remove your account & data',
 style: TextStyle(
 color: VSPColors.textSecondary.withValues(alpha: 0.8),
 fontSize: 11,
 ),
 ),
 ],
 ),
 ),
 TextButton(
 onPressed: () => _showDeleteAccountDialog(context),
 style: TextButton.styleFrom(
 backgroundColor: VSPColors.error,
 foregroundColor: Colors.white,
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

 void _showDeleteAccountDialog(BuildContext context) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';

 showDialog(
 context: context,
 builder: (context) => StatefulBuilder(
 builder: (context, setDialogState) {
 return AlertDialog(
 backgroundColor: VSPColors.surface,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
 title: Text(
 isArabic ? 'حذف الحساب نهائياً؟ ' : 'Delete Account?', 
 style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold),
 ),
 content: Text(
 isArabic 
 ? 'هل أنت متأكد؟ لا يمكن التراجع عن هذا الإجراء وسيتم حذف جميع بياناتك وفريقك وتاريخ مبارياتك نهائياً.' 
 : 'Are you sure? This action cannot be undone. You will lose all your data, teams, and match history permanently.',
 style: const TextStyle(color: VSPColors.textSecondary, height: 1.5),
 ),
 actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
 actions: [
 Row(
 children: [
 Expanded(
 child: PrimaryButton(
 text: isArabic ? 'إلغاء' : 'Cancel',
 height: 48,
 color: VSPColors.surfaceAlt,
 textColor: VSPColors.textPrimary,
 onPressed: _isDeleting ? null : () => Navigator.pop(context),
 ),
 ),
 const SizedBox(width: VSPSpacing.md),
 Expanded(
 child: PrimaryButton(
 text: isArabic ? 'حذف' : 'Delete',
 height: 48,
 color: VSPColors.error,
 textColor: VSPColors.background,
 isLoading: _isDeleting,
 onPressed: _isDeleting ? null : () async {
 setDialogState(() => _isDeleting = true);
 final authProvider = Provider.of<AuthProvider>(context, listen: false);
 final success = await authProvider.deleteAccount();
 
 if (!context.mounted) return;
 
 if (success) {
 Navigator.of(context).pushAndRemoveUntil(
 MaterialPageRoute(builder: (_) => const WelcomeScreen()),
 (route) => false,
 );
 } else {
 setDialogState(() => _isDeleting = false);
 VSPFeedback.showError(context, authProvider.errorMessage ?? (isArabic ? "فشل حذف الحساب" : "Failed to delete account"));
 Navigator.pop(context);
 }
 },
 ),
 ),
 ],
 ),
 ],
 );
 }
 ),
 );
 }
}

