import 'add_stadium_wizard.dart';
import '../../../shared/widgets/stadium_card.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../auth/screens/welcome_screen.dart';
import '../../../shared/widgets/custom_text_field.dart';

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
  bool _isDeleting = false;
  bool _isLocating = false;
  List<Stadium> _stadiums = [];

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
    
    final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);
    _stadiums = stadiumProvider.stadiums;
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
            ? "يجب إدخال طريقة دفع واحدة على الأقل (محفظة، إنستا باي، أو تحويل بنكي) لحفظ البيانات وتفعيل استقبال الحجوزات ⚠️"
            : "You must enter at least one payment method (Wallet, InstaPay, or Bank) to save settings ⚠️",
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
        VSPFeedback.showSuccess(context, isArabic ? 'تم تحديث البيانات بنجاح 🛡️' : 'Profile updated successfully');
        Navigator.pop(context);
      } else {
        VSPFeedback.showError(context, isArabic ? 'فشل تحديث البيانات' : 'Failed to update profile');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userModel = authProvider.userModel;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          isArabic ? 'الحساب' : 'Account',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Stadium Selector
            if (_stadiums.isNotEmpty)
              SizedBox(
                height: 230,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 0),
                  scrollDirection: Axis.horizontal,
                  itemCount: _stadiums.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 310,
                      margin: const EdgeInsets.only(right: VSPSpacing.md),
                      child: GestureDetector(
                        onTap: () { 
                          Navigator.push(context, MaterialPageRoute(builder: (_) => AddStadiumWizard(stadiumId: _stadiums[index].id))); 
                        }, 
                        child: StadiumCard(stadium: _stadiums[index], isOwnerView: false),
                      ),
                    );
                  },
                ),
              ),
            
            const SizedBox(height: 20),

            // 2. Personal Info Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildInputLabel(isArabic ? 'اسم المالك' : 'Owner Name'),
                   CustomTextField(controller: _nameController, hintText: isArabic ? 'أدخل اسمك' : 'Enter your name'),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel(isArabic ? 'رقم الهاتف' : 'Phone Number'),
                   CustomTextField(controller: _phoneController, hintText: isArabic ? 'أدخل رقم هاتفك' : 'Enter your phone', keyboardType: TextInputType.phone),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel(isArabic ? 'البريد الإلكتروني' : 'Email Address'),
                   CustomTextField(controller: _emailController, hintText: isArabic ? 'أدخل بريدك الإلكتروني' : 'Enter your email', suffixIcon: Icon(LucideIcons.lock, size: 18, color: VSPColors.textSecondary)),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel(isArabic ? 'الموقع' : 'Location'),
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
                                 userModel?.governorate ?? (isArabic ? 'غير محدد' : 'Not set'),
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
                             await authProvider.updateUserLocation();
                             if (mounted) {
                               if (!context.mounted) return;
                               setState(() => _isLocating = false);
                               VSPFeedback.showSuccess(context, isArabic ? 'تم تحديث الموقع!' : 'Location updated!');
                             }
                           },
                         ),
                       ],
                     ),
                   ),
                   
                   const SizedBox(height: 16),
                   _buildInputLabel(isArabic ? 'روابط التواصل الاجتماعي' : 'Social media'),
                   CustomTextField(controller: _socialController, hintText: isArabic ? 'أدخل رابط التواصل الاجتماعي' : 'Enter social media link'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // P2P Receivables Settings
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: VSPCard(
                padding: const EdgeInsets.all(VSPSpacing.md),
                margin: EdgeInsets.zero,
                color: VSPColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'إعدادات تحصيل مستحقات P2P' : 'P2P Receivables Settings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: VSPColors.accent),
                    ),
                    const SizedBox(height: 16),
                    _buildInputLabel(isArabic ? '📲 عنوان إنستا باي (InstaPay IPN / Phone)' : '📲 InstaPay IPN / Phone'),
                    CustomTextField(
                      controller: _instapayController,
                      hintText: isArabic ? 'أدخل عنوان إنستا باي أو الهاتف' : 'Enter InstaPay IPN or phone number',
                      suffixIcon: _instapayController.text.isNotEmpty 
                        ? IconButton(icon: const Icon(LucideIcons.x, size: 16), onPressed: () => setState(() => _instapayController.clear()))
                        : null,
                    ),
                    const SizedBox(height: 16),
                    _buildInputLabel(isArabic ? '💵 رقم محفظة فودافون كاش (Vodafone Cash Number)' : '💵 Vodafone Cash Number'),
                    CustomTextField(
                      controller: _vodafoneController,
                      hintText: isArabic ? 'أدخل رقم المحفظة' : 'Enter Vodafone Cash number',
                      keyboardType: TextInputType.phone,
                      suffixIcon: _vodafoneController.text.isNotEmpty 
                        ? IconButton(icon: const Icon(LucideIcons.x, size: 16), onPressed: () => setState(() => _vodafoneController.clear()))
                        : null,
                    ),
                    const SizedBox(height: 16),
                    _buildInputLabel(isArabic ? '🏦 الحساب البنكي / المستفيد (IBAN & Holder)' : '🏦 Bank Account Number/IBAN & Holder Name'),
                    CustomTextField(
                      controller: _bankController,
                      hintText: isArabic ? 'أدخل تفاصيل الحساب واسم المستفيد' : 'Enter Bank Account/IBAN and Holder Name',
                      suffixIcon: _bankController.text.isNotEmpty 
                        ? IconButton(icon: const Icon(LucideIcons.x, size: 16), onPressed: () => setState(() => _bankController.clear()))
                        : null,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 3. Documents
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildInputLabel(isArabic ? 'الجهة الأمامية للبطاقة الشخصية' : 'National ID Front'),
                   _buildDocumentCard(isArabic ? 'الجهة الأمامية للبطاقة الشخصية' : 'National ID Front', '500 KB'),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel(isArabic ? 'الجهة الخلفية للبطاقة الشخصية' : 'National ID Back'),
                   _buildDocumentCard(isArabic ? 'الجهة الخلفية للبطاقة الشخصية' : 'National ID Back', '500 KB'),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel(isArabic ? 'البطاقة الضريبية' : 'Tax Card'),
                   _buildDocumentCard(isArabic ? 'البطاقة الضريبية' : 'Tax Card', '300 KB'),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel(isArabic ? 'السجل التجاري' : 'Commercial Register'),
                   _buildDocumentCard(isArabic ? 'السجل التجاري' : 'Commercial Register', '200 KB'),

                   const SizedBox(height: 40),

                   // --- Delete Account Button ---
                   Center(
                      child: TextButton(
                        onPressed: () => _showDeleteAccountDialog(context),
                        child: Text(
                          isArabic ? 'حذف الحساب' : 'Delete Account',
                          style: const TextStyle(
                            color: VSPColors.error,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, MediaQuery.of(context).padding.bottom + VSPSpacing.md),
        color: VSPColors.background,
        child: PrimaryButton(
          text: isArabic ? 'تأكيد' : 'Confirm',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _updateUserData,
        ),
      ),
    );
  }
  
  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VSPSpacing.xs, left: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
      ),
    );
  }

  Widget _buildDocumentCard(String title, String size) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return VSPCard(
      padding: const EdgeInsets.all(VSPSpacing.md),
      margin: EdgeInsets.zero,
      color: VSPColors.accent.withValues(alpha: 0.05),
      border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2)),
      child: Row(
        children: [
           Icon(LucideIcons.image, color: VSPColors.textPrimary, size: 24),
           const SizedBox(width: VSPSpacing.md),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(title, style: Theme.of(context).textTheme.titleSmall),
                 Text(size, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                 const SizedBox(height: 4),
                 GestureDetector(
                   onTap: () {
                     // View logic
                   },
                   child: Text(
                     isArabic ? 'اضغط للعرض' : 'Click to view',
                     style: Theme.of(context).textTheme.labelMedium?.copyWith(
                       color: VSPColors.accent,
                       fontWeight: FontWeight.bold,
                       decoration: TextDecoration.underline,
                     ),
                   ),
                 ),
               ],
             ),
           )
        ],
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
              isArabic ? 'حذف حساب المالك نهائياً؟ ⚠️' : 'Delete Account?', 
              style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold),
            ),
            content: Text(
              isArabic
                  ? 'هل أنت متأكد؟ لا يمكن التراجع عن هذا الإجراء وسيتم حذف جميع بياناتك وملاعبك وتاريخ حجوزاتك نهائياً.'
                  : 'Are you sure? This action cannot be undone. You will lose all your data, stadiums, and match history permanently.',
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
