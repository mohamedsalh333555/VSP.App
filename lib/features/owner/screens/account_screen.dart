import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import 'add_stadium_wizard.dart';
import 'subscription_plans_screen.dart';
import '../../../core/utils/vsp_feedback.dart';

import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/stadium_card.dart';
import '../../../core/repositories/stadium_repository.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _socialController;
  bool _isLoading = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;

    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _addressController = TextEditingController(text: user?.governorate ?? '');
    _socialController = TextEditingController(text: user?.additionalData?['socialMedia'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _socialController.dispose();
    super.dispose();
  }

  Future<void> _saveData() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      VSPFeedback.showError(context, 'Name cannot be empty');
      return;
    }
    if (phone.isEmpty) {
      VSPFeedback.showError(context, 'Phone number cannot be empty');
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.updateProfile({
      'name': name,
      'phone': phone,
      'governorate': _addressController.text.trim(),
      'additionalData': {
        ...authProvider.userModel?.additionalData ?? {},
        'socialMedia': _socialController.text.trim(),
      }
    });

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        VSPFeedback.showSuccess(context, 'Changes Saved Successfully');
        Navigator.pop(context);
      } else {
        VSPFeedback.showError(context, 'Failed to save changes');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentOwnerId = auth.currentUser?.uid ?? auth.userModel?.uid ?? '';
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left_2_copy, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isArabic ? 'الحساب' : 'Account',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stadiums Carousel Header
            Text(
              isArabic ? 'الملاعب المسجلة' : 'My Stadiums',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Stadiums & Add New Stadium Fawry-style Carousel
            SizedBox(
              height: 215,
              child: StreamBuilder<List<Stadium>>(
                stream: currentOwnerId.isNotEmpty
                    ? StadiumRepository().getOwnerStadiums(currentOwnerId)
                    : Stream.value([]),
                builder: (context, snapshot) {
                  final stadiums = snapshot.data ?? [];
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: stadiums.length + 1,
                    itemBuilder: (context, index) {
                      if (index < stadiums.length) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 260,
                            child: StadiumCard(
                              stadium: stadiums[index],
                              isOwnerView: true,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddStadiumWizard(stadiumId: stadiums[index].id),
                                  ),
                                );
                              },
                              onEditTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddStadiumWizard(stadiumId: stadiums[index].id),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      } else {
                        // Fawry-style Add Stadium Plus Card
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _buildAddStadiumCard(context, stadiums.length),
                        );
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Owner Info Form
            _buildLabel(context, isArabic ? 'اسم المالك' : 'Owner Name'),
            CustomTextField(controller: _nameController, hintText: isArabic ? 'أدخل اسمك' : 'Enter your name'),
            const SizedBox(height: 16),

            _buildLabel(context, isArabic ? 'رقم الهاتف' : 'Phone Number'),
            CustomTextField(controller: _phoneController, hintText: isArabic ? 'أدخل رقم هاتفك' : 'Enter your phone', keyboardType: TextInputType.phone),
            const SizedBox(height: 16),

            _buildLabel(context, isArabic ? 'البريد الإلكتروني' : 'Email Address'),
            CustomTextField(controller: _emailController, hintText: isArabic ? 'أدخل بريدك الإلكتروني' : 'Enter your email', enabled: false, suffixIcon: Icon(Iconsax.lock_copy, size: 18, color: VSPColors.textSecondary)),
            const SizedBox(height: 16),

            _buildLabel(context, isArabic ? 'الموقع' : 'Location'),
            Container(
              padding: const EdgeInsets.all(VSPSpacing.md),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.divider.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Icon(Iconsax.location_copy, color: VSPColors.accent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'المحافظة الحالية' : 'Current Governorate',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                        ),
                        Text(
                          _addressController.text.isEmpty ? (isArabic ? 'غير محدد' : 'Not set') : _addressController.text,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  _isLocating 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent))
                  : IconButton(
                    icon: Icon(Iconsax.gps_copy, color: VSPColors.accent),
                    onPressed: () async {
                      setState(() => _isLocating = true);
                      await Provider.of<AuthProvider>(context, listen: false).updateUserLocation();
                      if (mounted) {
                        if (!context.mounted) return;
                        setState(() {
                          _addressController.text = Provider.of<AuthProvider>(context, listen: false).governorate;
                          _isLocating = false;
                        });
                        VSPFeedback.showSuccess(context, isArabic ? 'تم تحديث الموقع!' : 'Location updated!');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildLabel(context, isArabic ? 'روابط التواصل الاجتماعي' : 'Social media'),
            CustomTextField(controller: _socialController, hintText: isArabic ? 'أدخل رابط التواصل الاجتماعي' : 'Enter social media link'),
            const SizedBox(height: 24),

            const SizedBox(height: 32),

            PrimaryButton(
              text: isArabic ? 'تأكيد' : 'Confirm',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _saveData,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
     return Padding(
        padding: const EdgeInsets.only(bottom: VSPSpacing.xs),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
        ),
     );
  }

  void _handleAddStadiumTap(BuildContext context, int currentCount) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userModel;

    final isPro = user?.isProPlan == true;
    final canAddMore = isPro ? currentCount < 3 : currentCount < 1;

    if (canAddMore || currentCount == 0) {
      // Open Add Stadium Wizard
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AddStadiumWizard(),
        ),
      );
    } else if (!isPro) {
      // Show Fawry-style Upgrade Modal to Pro Plan (1000 EGP)
      _showUpgradePlanModal(context, isArabic);
    } else {
      // Reached max 3 stadiums for Pro plan
      VSPFeedback.showSuccess(
        context,
        isArabic
            ? 'وصلت للحد الأقصى المسموح (3 ملاعب). لتخصيص خطة أعلى تواصل مع الدعم.'
            : 'Maximum 3 stadiums limit reached. Contact support for enterprise plans.',
      );
    }
  }

  /// ➕ Fawry Wallet-Style Add Stadium Plus Card
  Widget _buildAddStadiumCard(BuildContext context, int currentCount) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return GestureDetector(
      onTap: () => _handleAddStadiumTap(context, currentCount),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.xl),
          border: Border.all(
            color: VSPColors.accent.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: VSPColors.accent.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Plus Circle Icon with Fawry Glow
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: VSPColors.accent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: VSPColors.accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Iconsax.add_circle_copy,
                color: VSPColors.accent,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isArabic ? 'إضافة ملعب آخر' : 'Add Another Stadium',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 💎 Fawry Upgrade Modal
  void _showUpgradePlanModal(BuildContext context, bool isArabic) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber, width: 2),
                ),
                child: const Icon(Iconsax.crown_copy, color: Colors.amber, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                isArabic ? 'ترقية الباقة لإضافة ملاعب أخرى' : 'Upgrade Plan to Add More Stadiums',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                isArabic
                    ? 'الباقة الأساسية (500 ج.م / 3 شهور مجاناً) تتيح تشغيل ملعب واحد فقط.\n\nترقية حسابك للباقة الاحترافية (1000 ج.م) لإضافة حتى 3 ملاعب كاملة وإدارتها من مكان واحد!'
                    : 'Basic Plan allows 1 stadium only.\n\nUpgrade to Pro Plan (1000 EGP) to add up to 3 stadiums and manage your full multi-pitch complex!',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: isArabic ? 'ترقية إلى باقة 1000 ج.م 🚀' : 'Upgrade to Pro 1000 EGP 🚀',
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(
                  isArabic ? 'إلغاء' : 'Cancel',
                  style: const TextStyle(color: VSPColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


