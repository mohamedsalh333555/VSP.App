import 'dart:io';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';
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
  String _selectedPosition = 'GK';
  final List<String> _positions = ['GK', 'DF', 'MF', 'FW'];
  
  bool _isLoading = false;
  bool _isDeleting = false;
  XFile? _newProfileImage;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    if (user?.position != null && _positions.contains(user!.position)) {
      _selectedPosition = user.position!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
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
      final success = await auth.updateProfile({
        'name': name,
        'phone': PhoneUtils.normalize(phone),
        'position': _selectedPosition,
      });

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: VSPColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
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
            bottom: MediaQuery.of(context).viewInsets.bottom + VSPSpacing.lg, // Keyboard protection
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
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const CircularProgressIndicator(color: VSPColors.accent),
                                    errorWidget: (context, url, error) => const Icon(Icons.person, size: 50, color: VSPColors.textSecondary),
                                  )
                                : const Icon(Icons.person, size: 50, color: VSPColors.textSecondary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: VSPColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: VSPColors.background, width: 3),
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.black),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: VSPSpacing.xxl),

              // --- Form Fields ---
              Align(
                alignment: Alignment.centerLeft,
                child: Text(AppLocalizations.of(context)!.fullName, style: Theme.of(context).textTheme.labelMedium),
              ),
              const SizedBox(height: VSPSpacing.xs),
              CustomTextField(
                controller: _nameController,
                hintText: AppLocalizations.of(context)!.enterName,
                prefixIcon: Icons.person_outline,
              ),

              const SizedBox(height: VSPSpacing.md),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(AppLocalizations.of(context)!.phoneNumber, style: Theme.of(context).textTheme.labelMedium),
              ),
              const SizedBox(height: VSPSpacing.xs),
              CustomTextField(
                controller: _phoneController,
                hintText: AppLocalizations.of(context)!.enterPhone,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
              ),

              const SizedBox(height: VSPSpacing.md),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(AppLocalizations.of(context)!.preferredPosition, style: Theme.of(context).textTheme.labelMedium),
              ),
              const SizedBox(height: VSPSpacing.xs),
              
              // Position Dropdown
              Container(
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPosition,
                    dropdownColor: VSPColors.surface,
                    icon: const Icon(Icons.keyboard_arrow_down, color: VSPColors.textSecondary),
                    isExpanded: true,
                    style: Theme.of(context).textTheme.bodyMedium,
                    items: _positions.map((String pos) {
                      return DropdownMenuItem<String>(
                        value: pos,
                        child: Text(pos),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedPosition = newValue;
                        });
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // --- Save Button ---
              PrimaryButton(
                text: AppLocalizations.of(context)!.saveChanges,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _saveChanges,
              ),

              const SizedBox(height: VSPSpacing.lg),

              // --- Delete Account Button ---
              TextButton(
                onPressed: () => _showDeleteAccountDialog(context),
                child: const Text(
                  'Delete Account',
                  style: TextStyle(
                    color: VSPColors.error,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: VSPColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
            title: const Text('Delete Account?', style: TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold)),
            content: const Text(
              'Are you sure? This action cannot be undone. You will lose all your data, teams, and match history permanently.',
              style: TextStyle(color: VSPColors.textSecondary, height: 1.5),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      text: 'Cancel',
                      height: 48,
                      color: VSPColors.surfaceAlt,
                      textColor: VSPColors.textPrimary,
                      onPressed: _isDeleting ? null : () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: VSPSpacing.md),
                  Expanded(
                    child: PrimaryButton(
                      text: 'Delete',
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
                          VSPFeedback.showError(context, authProvider.errorMessage ?? "Failed to delete account");
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
