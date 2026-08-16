import 'add_stadium_wizard.dart';
import 'subscription_plans_screen.dart';
import '../../../shared/widgets/stadium_card.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../auth/screens/welcome_screen.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../core/repositories/stadium_repository.dart';

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
            ? 'خطأ: لا يمكن مسح أو ترك جميع وسائل التسوية المالية فارغة! ⚠️\nيجب إدخال وسيلة تحصيل واحدة على الأقل (إنستا باي، محفظة إلكترونية، أو حساب بنكي) لاستلام أرباحك.'
            : 'Error: Payout methods cannot all be empty! ⚠️ Please provide at least one method (InstaPay, Mobile Wallet, or Bank IBAN).',
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
          icon: Icon(isArabic ? Iconsax.arrow_right_1_copy : Iconsax.arrow_left_copy, color: VSPColors.textPrimary),
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
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Stadium Selector & Fawry-style Add Stadium Plus Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                isArabic ? 'الملاعب المسجلة' : 'My Stadiums',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),

            Builder(builder: (context) {
              final currentUid = Provider.of<AuthProvider>(context, listen: false).currentUser?.uid ?? '';
              return SizedBox(
                height: 215,
                child: StreamBuilder<List<Stadium>>(
                  stream: currentUid.isNotEmpty
                      ? StadiumRepository().getOwnerStadiums(currentUid)
                      : Stream.value([]),
                  builder: (context, snapshot) {
                    final stadiums = snapshot.data ?? [];
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 0),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: stadiums.length + 1,
                      itemBuilder: (context, index) {
                        if (index < stadiums.length) {
                          return Container(
                            width: 260,
                            margin: const EdgeInsets.only(right: VSPSpacing.md),
                            child: StadiumCard(
                              stadium: stadiums[index],
                              isOwnerView: true,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => AddStadiumWizard(stadiumId: stadiums[index].id)));
                              },
                              onEditTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => AddStadiumWizard(stadiumId: stadiums[index].id)));
                              },
                            ),
                          );
                        } else {
                          return Container(
                            width: 240,
                            margin: const EdgeInsets.only(right: VSPSpacing.md),
                            child: _buildAddStadiumCard(context, stadiums.length),
                          );
                        }
                      },
                    );
                  },
                ),
              );
            }),
            
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
                   CustomTextField(controller: _emailController, hintText: isArabic ? 'أدخل بريدك الإلكتروني' : 'Enter your email', suffixIcon: Icon(Iconsax.lock_copy, size: 18, color: VSPColors.textSecondary)),
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
                                 userModel?.governorate ?? (isArabic ? 'غير محدد' : 'Not set'),
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

            // Owner Payout & Settlement Information
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: VSPCard(
                padding: const EdgeInsets.all(VSPSpacing.md),
                margin: EdgeInsets.zero,
                color: VSPColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.wallet_1_copy, color: VSPColors.accent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isArabic ? 'بيانات استلام المستحقات والتسويات المالية 🏦' : 'Payout & Settlement Method',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: VSPColors.accent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isArabic 
                          ? 'تستخدم هذه البيانات من قبل إدارة المنصة VSP لتحويل أرباح ومستحقات حجز ملاعبك إليك بشكل دوري.'
                          : 'This data is used by VSP Admin to disburse your stadium booking payouts.',
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    _buildInputLabel(isArabic ? '📲 عنوان إنستا باي (InstaPay IPN / Phone)' : '📲 InstaPay IPN / Phone'),
                    CustomTextField(
                      controller: _instapayController,
                      hintText: isArabic ? 'أدخل عنوان إنستا باي أو الهاتف' : 'Enter InstaPay IPN or phone number',
                      suffixIcon: _instapayController.text.isNotEmpty 
                        ? IconButton(icon: const Icon(Iconsax.close_circle_copy, size: 16), onPressed: () => setState(() => _instapayController.clear()))
                        : null,
                    ),
                    const SizedBox(height: 16),
                    _buildInputLabel(isArabic ? '💵 رقم المحفظة الإلكترونية (فودافون كاش / اتصالات / أورنج)' : '💵 Mobile Wallet Number'),
                    CustomTextField(
                      controller: _vodafoneController,
                      hintText: isArabic ? 'أدخل رقم المحفظة' : 'Enter wallet phone number',
                      keyboardType: TextInputType.phone,
                      suffixIcon: _vodafoneController.text.isNotEmpty 
                        ? IconButton(icon: const Icon(Iconsax.close_circle_copy, size: 16), onPressed: () => setState(() => _vodafoneController.clear()))
                        : null,
                    ),
                    const SizedBox(height: 16),
                    _buildInputLabel(isArabic ? '🏦 الحساب البنكي / المستفيد (IBAN & Holder)' : '🏦 Bank Account Number / IBAN'),
                    CustomTextField(
                      controller: _bankController,
                      hintText: isArabic ? 'أدخل تفاصيل الحساب واسم المستفيد' : 'Enter Bank Account/IBAN and Holder Name',
                      suffixIcon: _bankController.text.isNotEmpty 
                        ? IconButton(icon: const Icon(Iconsax.close_circle_copy, size: 16), onPressed: () => setState(() => _bankController.clear()))
                        : null,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- Delete Account Danger Zone Card ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                width: double.infinity,
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
                            isArabic ? 'حذف كافة البيانات والملاعب السابقة' : 'Permanently remove profile & stadiums',
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
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, MediaQuery.of(context).padding.bottom + VSPSpacing.md),
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
  
  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VSPSpacing.xs, left: 4),
      child: Text(
        label,
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
                    ? 'الباقة الأساسية (500 ج.م / شهرين مجاناً) تتيح تشغيل ملعب واحد فقط.\n\nترقية حسابك للباقة الاحترافية (1000 ج.م) لإضافة حتى 3 ملاعب كاملة وإدارتها من مكان واحد!'
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
