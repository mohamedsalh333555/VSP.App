import '../../../shared/widgets/vsp_terms_checkbox.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../shared/widgets/vsp_auth_header.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/constants/egypt_governorates.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../shared/widgets/vsp_date_picker_dialog.dart';
import '../widgets/owner_onboarding/owner_onboarding_exit_dialog.dart';
import '../widgets/owner_onboarding/owner_onboarding_location_section.dart';

class OwnerOnboardingScreen extends StatefulWidget {
  const OwnerOnboardingScreen({super.key});

  @override
  State<OwnerOnboardingScreen> createState() => _OwnerOnboardingScreenState();
}

class _OwnerOnboardingScreenState extends State<OwnerOnboardingScreen> {
  bool _agreedToTerms = false;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedGovernorate = 'Cairo';
  bool _isLoading = false;
  bool _isFetchingLocation = false;
  bool _isLocationFallbackActive = false;
  DateTime? _dateOfBirth;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() => setState(() {}));
    _firstNameController.addListener(() => setState(() {}));
    _lastNameController.addListener(() => setState(() {}));
    Future.microtask(() => _fetchAutoLocation());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final displayName = auth.userModel?.name ?? auth.currentUser?.userMetadata?['name'] as String?;
      if (displayName != null && displayName.trim().isNotEmpty) {
        final parts = displayName.trim().split(' ');
        _firstNameController.text = parts.first;
        if (parts.length > 1) _lastNameController.text = parts.sublist(1).join(' ');
        setState(() {});
      }
    });
  }

  Future<void> _fetchAutoLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      final result = await Provider.of<AuthProvider>(context, listen: false).determineGPSGovernorate(force: true);
      if (result != null && EgyptGovernorates.allGovernorates.contains(result) && mounted) {
        setState(() {
          _selectedGovernorate = result;
          _isLocationFallbackActive = false;
        });
      } else {
        setState(() => _isLocationFallbackActive = true);
        HapticFeedback.lightImpact();
      }
    } catch (_) {
      setState(() => _isLocationFallbackActive = true);
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showVSPDatePicker(
      context,
      initialDate: _dateOfBirth ?? DateTime(1990),
      minYear: 1940,
      maxYear: DateTime.now().year - 18,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_agreedToTerms) {
      VSPFeedback.showError(context, l10n.pleaseAgreeToTerms);
      return;
    }
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      VSPFeedback.showError(context, l10n.fillAllFields);
      return;
    }
    if (_dateOfBirth == null) {
      VSPFeedback.showError(context, l10n.pleaseEnterDob);
      return;
    }
    if (phone.length < 9) {
      VSPFeedback.showError(context, l10n.invalidPhone);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final fullName = '$firstName $lastName';

      final success = await authProvider.completeSocialRegistration(
        phone: phone,
        name: fullName,
        governorate: _selectedGovernorate,
        dateOfBirth: _dateOfBirth,
      );

      if (!mounted) return;

      if (success) {
        HapticFeedback.lightImpact();
        if (mounted) {
          context.go('/facility-onboarding');
        }
      } else {
        HapticFeedback.vibrate();
        if (mounted) {
          VSPFeedback.showError(context, authProvider.errorMessage ?? (Localizations.localeOf(context).languageCode == 'ar' ? 'فشل إكمال التسجيل، يرجى المحاولة مجدداً' : 'Failed to complete registration, please try again'));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !context.mounted) return;
        final shouldSignOut = await OwnerOnboardingExitDialog.show(context);
        if (shouldSignOut == true) await auth.abortRegistration();
      },
      child: Scaffold(
        backgroundColor: VSPColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: 0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VSPAuthHeader(
                  showLogo: true,
                  onBack: () async {
                    final shouldSignOut = await OwnerOnboardingExitDialog.show(context);
                    if (shouldSignOut == true) await auth.abortRegistration();
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.completeYourOwnerProfile,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 32,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.ownerContactAndPayoutInfo,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: VSPColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _buildLabel(l10n.firstName),
                        CustomTextField(
                          controller: _firstNameController,
                          hintText: l10n.enterFirstName,
                          textInputAction: TextInputAction.next,
                          prefixIcon: Iconsax.user_copy,
                        ),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _buildLabel(l10n.lastName),
                        CustomTextField(
                          controller: _lastNameController,
                          hintText: l10n.enterLastName,
                          textInputAction: TextInputAction.next,
                          prefixIcon: Iconsax.user_copy,
                        ),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildLabel(l10n.dateOfBirth),
                _buildDatePicker(l10n),
                const SizedBox(height: 20),
                _buildLabel(l10n.phoneNumber),
                CustomTextField(
                  controller: _phoneController,
                  hintText: '01xxxxxxxxx',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  prefixIcon: Iconsax.call_copy,
                ),
                const SizedBox(height: 20),
                OwnerOnboardingLocationSection(
                  selectedGovernorate: _selectedGovernorate,
                  isFetchingLocation: _isFetchingLocation,
                  isLocationFallbackActive: _isLocationFallbackActive,
                  onGovernorateChanged: (v) => setState(() => _selectedGovernorate = v),
                  onAutoDetectTapped: _fetchAutoLocation,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).padding.bottom + 16),
          decoration: BoxDecoration(color: VSPColors.background, border: Border(top: BorderSide(color: VSPColors.divider.withValues(alpha: 0.1)))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VSPTermsCheckbox(
                value: _agreedToTerms,
                onChanged: (val) => setState(() => _agreedToTerms = val),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: PrimaryButton(
                  text: l10n.completeRegistration,
                  isLoading: _isLoading,
                  onPressed: _handleSubmit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(AppLocalizations l10n) {
    return GestureDetector(
      onTap: _pickDateOfBirth,
      child: Container(
        height: VSPSize.inputHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.input),
          border: Border.all(color: VSPColors.accent.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            const Icon(Iconsax.calendar_1_copy, color: VSPColors.textSecondary, size: 18),
            const SizedBox(width: 12),
            Text(
              _dateOfBirth != null
                  ? '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}'
                  : l10n.dateOfBirthPlaceholder,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _dateOfBirth != null ? VSPColors.textPrimary : VSPColors.textSecondary,
                  ),
            ),
            const Spacer(),
            if (_dateOfBirth != null) const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500)),
    );
  }
}
