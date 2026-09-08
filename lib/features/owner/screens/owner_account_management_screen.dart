import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../widgets/account/owner_avatar_header.dart';
import '../widgets/account/owner_delete_account_card.dart';
import '../widgets/account/owner_payout_settings_card.dart';
import '../widgets/account/owner_profile_form.dart';
import '../widgets/account/owner_stadiums_carousel.dart';

class OwnerAccountManagementScreen extends StatefulWidget {
  const OwnerAccountManagementScreen({super.key});

  @override
  State<OwnerAccountManagementScreen> createState() => _OwnerAccountManagementScreenState();
}

class _OwnerAccountManagementScreenState extends State<OwnerAccountManagementScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _socialController;
  late TextEditingController _instapayController;
  late TextEditingController _vodafoneController;
  late TextEditingController _bankController;

  bool _isLoading = false;
  bool _isLocating = false;

  Stream<List<Stadium>>? _ownerStadiumsStream;
  String? _lastStadiumsUid;

  Stream<List<Stadium>> _getOwnerStadiumsStream(String uid) {
    if (_ownerStadiumsStream != null && _lastStadiumsUid == uid) {
      return _ownerStadiumsStream!;
    }
    _lastStadiumsUid = uid;
    _ownerStadiumsStream = uid.isNotEmpty
        ? StadiumRepository().getOwnerStadiums(uid)
        : Stream.value([]);
    return _ownerStadiumsStream!;
  }

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userModel = authProvider.userModel;

    _nameController = TextEditingController(text: userModel?.name ?? '');
    _phoneController = TextEditingController(text: userModel?.phone ?? '');
    _emailController = TextEditingController(text: userModel?.email ?? '');
    _socialController = TextEditingController(text: userModel?.additionalData?['socialMedia'] ?? '');
    _instapayController = TextEditingController(text: userModel?.p2pInstapay ?? '');
    _vodafoneController = TextEditingController(text: userModel?.p2pVodafone ?? '');
    _bankController = TextEditingController(text: userModel?.p2pBank ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _socialController.dispose();
    _instapayController.dispose();
    _vodafoneController.dispose();
    _bankController.dispose();
    super.dispose();
  }

  Future<void> _updateUserData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final instapay = _instapayController.text.trim();
    final vodafone = _vodafoneController.text.trim();
    final bank = _bankController.text.trim();

    if (name.isEmpty) {
      VSPFeedback.showError(context, isArabic ? 'اسم المالك لا يمكن أن يكون فارغاً' : 'Name cannot be empty');
      return;
    }
    if (phone.isEmpty) {
      VSPFeedback.showError(context, isArabic ? 'رقم الهاتف لا يمكن أن يكون فارغاً' : 'Phone number cannot be empty');
      return;
    }
    if (instapay.isEmpty && vodafone.isEmpty && bank.isEmpty) {
      VSPFeedback.showError(
        context,
        isArabic
            ? 'خطأ: لا يمكن مسح أو ترك جميع وسائل التسوية المالية فارغة! \nيجب إدخال وسيلة تحصيل واحدة على الأقل (إنستا باي، محفظة إلكترونية، أو حساب بنكي) لاستلام أرباحك.'
            : 'Error: Payout methods cannot all be empty! Please provide at least one method (InstaPay, Mobile Wallet, or Bank IBAN).',
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await authProvider.updateProfile({
      'name': name,
      'phone': phone,
      'p2p_instapay': instapay,
      'p2p_vodafone': vodafone,
      'p2p_bank': bank,
      'additionalData': {
        ...authProvider.userModel?.additionalData ?? {},
        'socialMedia': _socialController.text.trim(),
      }
    });

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        VSPFeedback.showSuccess(context, isArabic ? 'تم تحديث البيانات بنجاح ' : 'Profile updated successfully');
        Navigator.pop(context);
      } else {
        VSPFeedback.showError(context, isArabic ? 'فشل تحديث البيانات' : 'Failed to update profile');
      }
    }
  }

  Future<void> _updateLocation() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    setState(() => _isLocating = true);
    await authProvider.updateUserLocation();
    if (mounted) {
      setState(() => _isLocating = false);
      VSPFeedback.showSuccess(context, isArabic ? 'تم تحديث الموقع!' : 'Location updated!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userModel = authProvider.userModel;
    final currentUid = authProvider.currentUser?.uid ?? '';
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(
          isArabic ? 'الحساب' : 'Account',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Stadium Selector & Add Stadium Plus Card
            OwnerStadiumsCarousel(
              stadiumsStream: _getOwnerStadiumsStream(currentUid),
            ),
            const SizedBox(height: 20),

            // 2. Personal Info Form & Avatar
            OwnerAvatarHeader(auth: authProvider),
            const SizedBox(height: 20),
            OwnerProfileForm(
              nameController: _nameController,
              phoneController: _phoneController,
              emailController: _emailController,
              socialController: _socialController,
              governorate: userModel?.governorate,
              isLocating: _isLocating,
              onUpdateLocation: _updateLocation,
            ),
            const SizedBox(height: 24),

            // 3. Owner Payout & Settlement Information Card
            OwnerPayoutSettingsCard(
              instapayController: _instapayController,
              vodafoneController: _vodafoneController,
              bankController: _bankController,
            ),
            const SizedBox(height: 16),

            // 4. Delete Account Danger Zone Card
            const OwnerDeleteAccountCard(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          VSPSpacing.md,
          VSPSpacing.md,
          VSPSpacing.md,
          MediaQuery.of(context).padding.bottom + VSPSpacing.md,
        ),
        decoration: BoxDecoration(
          color: VSPColors.background,
          border: Border(top: BorderSide(color: VSPColors.divider.withValues(alpha: 0.2), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: PrimaryButton(
          text: isArabic ? 'تأكيد' : 'Confirm',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _updateUserData,
        ),
      ),
    );
  }
}
