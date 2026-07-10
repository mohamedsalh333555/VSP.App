import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/widgets/shimmer_image.dart';
import 'add_stadium_wizard.dart';
import '../../../core/utils/vsp_feedback.dart';

import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/stadium_card.dart';

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
    final stadiumProvider = Provider.of<StadiumProvider>(context);
    final stadiums = stadiumProvider.stadiums;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: VSPColors.textPrimary),
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
            // Stadiums List (Horizontal)
            SizedBox(
              height: 230,
              child: stadiums.isEmpty
                ? Center(child: Text(isArabic ? 'لم يتم إضافة ملاعب بعد' : 'No stadiums added yet'))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: stadiums.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: SizedBox(
                        width: 310,
                        child: StadiumCard(
                          stadium: stadiums[index],
                          isOwnerView: false,
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
                    ),
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
            CustomTextField(controller: _emailController, hintText: isArabic ? 'أدخل بريدك الإلكتروني' : 'Enter your email', enabled: false, suffixIcon: Icon(LucideIcons.lock, size: 18, color: VSPColors.textSecondary)),
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
                  Icon(LucideIcons.mapPin, color: VSPColors.accent, size: 28),
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
                    icon: Icon(LucideIcons.locate, color: VSPColors.accent),
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

            // Documents
            _buildLabel(context, isArabic ? 'الجهة الأمامية للبطاقة الشخصية' : 'National ID Front'),
            _buildDocCard(context, isArabic ? 'الجهة الأمامية للبطاقة الشخصية' : 'National ID Front'),
            const SizedBox(height: 12),

            _buildLabel(context, isArabic ? 'الجهة الخلفية للبطاقة الشخصية' : 'National ID Back'),
            _buildDocCard(context, isArabic ? 'الجهة الخلفية للبطاقة الشخصية' : 'National ID Back'),
            const SizedBox(height: 12),

            _buildLabel(context, isArabic ? 'البطاقة الضريبية' : 'Tax Card'),
            _buildDocCard(context, isArabic ? 'البطاقة الضريبية' : 'Tax Card'),
            const SizedBox(height: 12),

             _buildLabel(context, isArabic ? 'السجل التجاري' : 'Commercial Register'),
            _buildDocCard(context, isArabic ? 'السجل التجاري' : 'Commercial Register'),
            const SizedBox(height: 40),

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


  Widget _buildDocCard(BuildContext context, String name) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return VSPCard(
      padding: const EdgeInsets.all(VSPSpacing.md),
      color: VSPColors.accent.withValues(alpha: 0.05),
      border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2)),
      child: Row(
        children: [
          Icon(LucideIcons.image, color: VSPColors.textPrimary),
          const SizedBox(width: VSPSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleSmall),
              Text('200 KB', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
              Text(
                isArabic ? 'اضغط للعرض' : 'Click to view', 
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.accent, decoration: TextDecoration.underline),
              ),
            ],
          )
        ],
      ),
    );
  }
}


