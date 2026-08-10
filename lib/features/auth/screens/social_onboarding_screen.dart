import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';

import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/constants/egypt_governorates.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../shared/widgets/vsp_date_picker_dialog.dart';


class SocialOnboardingScreen extends StatefulWidget {
  const SocialOnboardingScreen({super.key});

  @override
  State<SocialOnboardingScreen> createState() => _SocialOnboardingScreenState();
}

class _SocialOnboardingScreenState extends State<SocialOnboardingScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _instapayController = TextEditingController();
  final _vodafoneController = TextEditingController();
  final _bankController = TextEditingController();
  String? _selectedPosition;
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

    // Smart split of Google/Apple display name
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
      if (result != null && mounted) {
        setState(() {
          _selectedGovernorate = result;
          _isLocationFallbackActive = false;
        });
      } else {
        setState(() {
          _isLocationFallbackActive = true;
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Error auto-fetching location: $e');
      setState(() {
        _isLocationFallbackActive = true;
      });
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showVSPDatePicker(
      context,
      initialDate: _dateOfBirth ?? DateTime(2000),
      minYear: 1940,
      maxYear: DateTime.now().year - 10,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _instapayController.dispose();
    _vodafoneController.dispose();
    _bankController.dispose();
    super.dispose();
  }



  bool get _isFormValid {
    final phone = _phoneController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    return phone.length == 11 && phone.startsWith("01") && firstName.isNotEmpty && lastName.isNotEmpty && _dateOfBirth != null && !_isLoading;
  }

  Future<void> _handleCompleteRegistration() async {
    if (!_isFormValid) return;

    final phone = _phoneController.text.trim();
    final fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isOwner = authProvider.isOwner;

    final success = await authProvider.completeSocialRegistration(
      phone: phone,
      name: fullName,
      position: authProvider.isPlayer ? _selectedPosition : null,
      governorate: _selectedGovernorate,
      dateOfBirth: _dateOfBirth,
      p2pInstapay: isOwner ? _instapayController.text.trim() : null,
      p2pVodafone: isOwner ? _vodafoneController.text.trim() : null,
      p2pBank: isOwner ? _bankController.text.trim() : null,
    );

    if (!mounted) return;

    if (success) {
      // Mark registration complete — GoRouter will automatically route to
      // /player or /owner via its redirect function once notifyListeners fires.
      if (authProvider.firebaseUser != null) {
        await authProvider.verifyEmailManual(authProvider.firebaseUser!.uid);
      }
      await authProvider.updateProfile({
        'isRegistrationComplete': true,
        'isEmailVerified': true,
      });
      // ✅ No imperative navigation needed — GoRouter handles it.
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage ?? 'Registration failed')),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isOwner = auth.isOwner;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldSignOut = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: AlertDialog(
                backgroundColor: VSPColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
                title: Row(
                  children: [
                    Icon(LucideIcons.logOut, color: VSPColors.warning),
                    const SizedBox(width: 10),
                    const Text(
                      'تأكيد الخروج؟',
                      style: TextStyle(
                        color: VSPColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                content: const Text(
                  'هل أنت متأكد من التراجع؟ ستحتاج إلى إدخال رقم هاتفك لتأكيد حسابك لاحقاً.',
                  style: TextStyle(
                    color: VSPColors.textSecondary,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(color: VSPColors.textSecondary),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VSPColors.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                    ),
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            );
          },
        );

        if (shouldSignOut == true) {
          await auth.signOut();
        }
      },
      child: Scaffold(
        backgroundColor: VSPColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0, // ✅ منع تغيير اللون عند السكرول
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: VSPColors.textPrimary),
            onPressed: () => Navigator.maybePop(context),
          ),
          actions: const [],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: 16.0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'أكمل ملفك الشخصي',
                  style: TextStyle(
                    color: VSPColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'بضع تفاصيل إضافية لتبدأ رحلتك',
                  style: TextStyle(color: VSPColors.textSecondary, fontSize: 16),
                ),
                const SizedBox(height: 32),

                // First & Last Name side-by-side
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('الاسم الأول'),
                          CustomTextField(
                            controller: _firstNameController,
                            hintText: 'محمد',
                            textInputAction: TextInputAction.next,
                            prefixIcon: LucideIcons.user,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('الاسم الثاني'),
                          CustomTextField(
                            controller: _lastNameController,
                            hintText: 'أحمد',
                            textInputAction: TextInputAction.next,
                            prefixIcon: LucideIcons.user2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Date of Birth
                const SizedBox(height: 20),
                _buildLabel('تاريخ الميلاد'),
                GestureDetector(
                  onTap: _pickDateOfBirth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: VSPColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.calendar, color: VSPColors.textSecondary, size: 18),
                        const SizedBox(width: 12),
                        Text(
                          _dateOfBirth != null
                              ? '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}'
                              : 'YYYY-MM-DD',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _dateOfBirth != null ? VSPColors.textPrimary : VSPColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        if (_dateOfBirth != null)
                          Icon(LucideIcons.checkCircle, color: VSPColors.accent, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildReadOnlyField('البريد الإلكتروني', auth.userModel?.email ?? auth.currentUser?.email ?? 'N/A'),
                
                const SizedBox(height: 20),
                _buildLabel('رقم الهاتف'),
                CustomTextField(
                  controller: _phoneController,
                  hintText: '01xxxxxxxxx',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  prefixIcon: LucideIcons.phone,
                ),
                           const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'المحافظة',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    if (_isFetchingLocation)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
                      )
                    else
                      GestureDetector(
                        onTap: _fetchAutoLocation,
                        child: const Icon(LucideIcons.locate, color: VSPColors.accent, size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isLocationFallbackActive) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: VSPColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: VSPColors.error.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      '⚠️ لم نتمكن من تحديد موقعك تلقائياً. يرجى اختيار محافظتك يدوياً لعرض الملاعب المناسبة لك.',
                      style: TextStyle(
                        color: VSPColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                _buildGovernorateDropdown(),

                if (isOwner) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(LucideIcons.wallet, color: VSPColors.accent, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'بيانات استلام المستحقات والتسويات المالية 🏦',
                                style: TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'يرجى إدخال وسيلة واحدة على الأقل لاستلام أرباح ومستحقات حجز ملاعبك دورياً من إدارة المنصة VSP.',
                          style: TextStyle(color: VSPColors.textSecondary, fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('عنوان انستا باي InstaPay IPN'),
                        CustomTextField(
                          controller: _instapayController,
                          hintText: 'username@instapay',
                          textInputAction: TextInputAction.next,
                          prefixIcon: LucideIcons.wallet,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('رقم المحفظة الإلكترونية (فودافون/اتصالات/أورنج)'),
                        CustomTextField(
                          controller: _vodafoneController,
                          hintText: '01xxxxxxxxx',
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          prefixIcon: LucideIcons.phoneCall,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('الحساب البنكي / IBAN واسم المستفيد'),
                        CustomTextField(
                          controller: _bankController,
                          hintText: 'EGxxxxxxxxxxxxxxxxxxxxxx',
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!_isLoading) _handleCompleteRegistration();
                          },
                          prefixIcon: LucideIcons.landmark,
                        ),
                      ],
                    ),
                  ),
                ],
                if (!isOwner) ...[
                  const SizedBox(height: 20),
                  _buildLabel('المركز المفضل'),
                  Builder(builder: (context) {
                    final isAr = Localizations.localeOf(context).languageCode == 'ar';
                    final positions = [
                      {'code': 'GK', 'label': isAr ? 'حارس' : 'GK'},
                      {'code': 'DF', 'label': isAr ? 'مدافع' : 'DF'},
                      {'code': 'MF', 'label': isAr ? 'خط وسط' : 'MF'},
                      {'code': 'FW', 'label': isAr ? 'مهاجم' : 'FW'},
                    ];

                    return Row(
                      children: positions.map((pos) {
                        final code = pos['code']!;
                        final label = pos['label']!;
                        final isSelected = _selectedPosition == code;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: ChoiceChip(
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(label, textAlign: TextAlign.center),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) setState(() => _selectedPosition = code);
                              },
                              selectedColor: VSPColors.accent,
                              backgroundColor: VSPColors.surface,
                              showCheckmark: false,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: isSelected ? VSPColors.background : VSPColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(VSPRadius.sm),
                                side: BorderSide(
                                  color: isSelected ? VSPColors.accent : VSPColors.divider,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).padding.bottom + 16),
          decoration: BoxDecoration(
            color: VSPColors.background,
            border: Border(top: BorderSide(color: VSPColors.divider.withValues(alpha: 0.1))),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: PrimaryButton(
              text: AppConfig.bypassOtp 
                ? 'إتمام وتحقق (وضع التطوير)' 
                : (isOwner ? 'متابعة لإعداد الملعب' : 'إتمام التسجيل'),
              isLoading: _isLoading,
              onPressed: () {
                final firstName = _firstNameController.text.trim();
                final lastName = _lastNameController.text.trim();
                final phone = _phoneController.text.trim();

                if (firstName.isEmpty || lastName.isEmpty) {
                  VSPFeedback.showError(context, 'يرجى إدخال الاسم بالكامل');
                  return;
                }
                if (_dateOfBirth == null) {
                  VSPFeedback.showError(context, 'يرجى إدخال تاريخ الميلاد 📅');
                  return;
                }
                if (!isOwner && _selectedPosition == null) {
                  VSPFeedback.showError(context, 'يرجى اختيار مركزك المفضل ⚽');
                  return;
                }
                if (phone.length < 10) {
                  VSPFeedback.showError(context, 'يرجى إدخال رقم هاتف صحيح 📱');
                  return;
                }
                if (isOwner &&
                    _instapayController.text.trim().isEmpty &&
                    _vodafoneController.text.trim().isEmpty &&
                    _bankController.text.trim().isEmpty) {
                  VSPFeedback.showError(context, 'يرجى إدخال وسيلة واحدة على الأقل لاستلام مستحقاتك المالية وتصفية الحسابات من المنصة 🏦');
                  return;
                }

                _handleCompleteRegistration();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: VSPColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: Border.all(color: VSPColors.divider),
          ),
          child: Text(
            value.isEmpty ? 'N/A' : value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildGovernorateDropdown() {
    final govs = EgyptGovernorates.allGovernorates;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: _isLocationFallbackActive ? VSPColors.accent : VSPColors.divider,
          width: _isLocationFallbackActive ? 2.0 : 1.0,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGovernorate,
          dropdownColor: VSPColors.surface,
          icon: Icon(LucideIcons.chevronDown, color: VSPColors.textSecondary),
          isExpanded: true,
          style: Theme.of(context).textTheme.bodyMedium,
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedGovernorate = newValue;
              });
            }
          },
          items: govs.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }
}

