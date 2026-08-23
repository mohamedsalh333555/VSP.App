import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../shared/widgets/social_auth_button.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';

import '../../../shared/widgets/vsp_back_button.dart';
import '../../../shared/widgets/vsp_icon_badge.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/utils/vsp_feedback.dart';

/// شاشة إنشاء حساب جديد - تظهر بعد اختيار الدور
class CreateAccountScreen extends StatefulWidget {
  final bool isOwner;

  const CreateAccountScreen({
    super.key,
    this.isOwner = false, // Default to player to be safe
  });

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  late TapGestureRecognizer _termsRecognizer;
  late TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = _onTermsOrPrivacyTap;
    _privacyRecognizer = TapGestureRecognizer()..onTap = _onTermsOrPrivacyTap;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<AuthProvider>(context, listen: false).setUserType(widget.isOwner ? 'owner' : 'player');
    });
  }

  void _onTermsOrPrivacyTap() {
    _showTermsAndPrivacyModal(context);
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool isUserOwner = widget.isOwner;

    // تحديد النصوص بناءً على نوع المستخدم
    final String greeting = !isUserOwner
        ? AppLocalizations.of(context)!.hiSporty
        : AppLocalizations.of(context)!.hiPitch;

    final String subtitle = !isUserOwner
        ? AppLocalizations.of(context)!.playerSubtitle
        : AppLocalizations.of(context)!.ownerSubtitle;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: VSPColors.background.withValues(alpha: 0),
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: VSPColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: VSPColors.background.withValues(alpha: 0),
      ),
      child: Scaffold(
        backgroundColor: VSPColors.background,
        body: Stack(
          children: [
            // 1. Subtle Background Elements
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: VSPColors.accentGlow,
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Container(color: VSPColors.background.withValues(alpha: 0)),
                ),
              ),
            ),
            
            // 2. Main Content
            SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    
                    // Header Nav
                    const Row(
                      children: [
                        VSPBackButton(),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Greeting Section
                    VSPFadeInItem(
                      index: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontSize: MediaQuery.of(context).size.width < 360 ? 38 : 46,
                              height: 0.9,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.createNewAccount,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: VSPColors.textSecondary,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Subtitle - Clean text under title
                    VSPFadeInItem(
                      index: 2,
                      child: Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: VSPColors.textSecondary,
                          height: 1.5,
                          fontSize: 15,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    VSPFadeInItem(
                      index: 3,
                      child: PrimaryButton(
                        text: AppLocalizations.of(context)!.continueWithEmail,
                        height: 60,
                        onPressed: () {
                          authProvider.setUserType(isUserOwner ? 'owner' : 'player');
                          context.push(isUserOwner ? '/signup-owner' : '/signup-player');
                        },
                      ),
                    ),

                    const SizedBox(height: 32),

                    VSPFadeInItem(
                      index: 4,
                      child: Row(
                        children: [
                          const Expanded(child: Divider(color: VSPColors.borderMedium)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              AppLocalizations.of(context)!.or,
                              style: TextStyle(
                                color: VSPColors.textSecondary.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: VSPColors.borderMedium)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Social Sign-In Buttons (Google & Apple)
                    VSPFadeInItem(
                      index: 5,
                      child: Row(
                        children: [
                          // 🟢 زر Apple يظهر فقط إذا كان الجهاز آيفون أو ماك
                          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
                            Expanded(
                              child: SocialAuthButton(
                                height: 56,
                                iconWidget: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/images/apple_logo.png',
                                      width: 20,
                                      height: 20,
                                      color: VSPColors.textPrimary,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Apple',
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: VSPColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                onPressed: () async {
                                  final role = isUserOwner ? 'owner' : 'player';
                                  authProvider.setUserType(role);
                                  await SecureStorageService.writeSecure('pending_oauth_role', role);
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('pending_oauth_role', role);
                                  await prefs.setBool('pending_oauth_is_login_only', false);
                                  final success = await authProvider.signInWithApple(isLoginOnly: false);
                                  if (context.mounted && !success) {
                                    VSPFeedback.showError(context, authProvider.errorMessage ?? 'Apple Sign-In failed');
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          
                          // 🟢 زر Google يظهر للجميع
                          Expanded(
                            child: SocialAuthButton(
                              height: 56,
                              iconWidget: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/google_logo.png',
                                    width: 22,
                                    height: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    AppLocalizations.of(context)!.google,
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: VSPColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              onPressed: () async {
                                final role = isUserOwner ? 'owner' : 'player';
                                authProvider.setUserType(role);
                                await SecureStorageService.writeSecure('pending_oauth_role', role);
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setString('pending_oauth_role', role);
                                await prefs.setBool('pending_oauth_is_login_only', false);
                                final success = await authProvider.signInWithGoogle(isLoginOnly: false);
                                if (context.mounted && !success) {
                                  VSPFeedback.showError(context, authProvider.errorMessage ?? 'Google Sign-In failed');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Footer Links
                    VSPFadeInItem(
                      index: 6,
                      child: Center(
                        child: Opacity(
                          opacity: 0.6,
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: VSPColors.textSecondary,
                                height: 1.5,
                              ),
                              children: [
                                TextSpan(text: AppLocalizations.of(context)!.byUsingVsp),
                                TextSpan(
                                  text: AppLocalizations.of(context)!.termsOfService,
                                  recognizer: _termsRecognizer,
                                  style: const TextStyle(
                                    color: VSPColors.accent,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                TextSpan(text: AppLocalizations.of(context)!.and),
                                TextSpan(
                                  text: AppLocalizations.of(context)!.privacyPolicy,
                                  recognizer: _privacyRecognizer,
                                  style: const TextStyle(
                                    color: VSPColors.accent,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// pop-up Modal (Dialog) displaying Terms of Service & Privacy Policy matching VSP design system
  void _showTermsAndPrivacyModal(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        final isAr = Localizations.localeOf(dialogContext).languageCode == 'ar';
        final titleText = isAr ? 'الشروط وأحكام الخصوصية' : 'Terms & Privacy Policy';
        final buttonText = isAr ? 'موافق' : 'I Understand';

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.xl),
                border: Border.all(color: VSPColors.divider, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                    child: Row(
                      children: [
                        const VSPIconBadge(icon: Iconsax.security_safe_copy, color: VSPColors.accent, size: 36, iconSize: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            titleText,
                            style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                              color: VSPColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: VSPColors.divider, height: 1),

                  // Content Body
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Badge
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: VSPColors.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(VSPRadius.lg),
                              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Iconsax.info_circle_copy, color: VSPColors.accent, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    isAr
                                        ? 'مطابق لقوانين وحماية البيانات المصرية (PDPL 2020)'
                                        : 'Compliant with Egyptian Data Protection Law (PDPL 2020)',
                                    style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                                      color: VSPColors.accent,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (widget.isOwner) ...[
                            _buildModalSectionCard(
                              dialogContext,
                              icon: Iconsax.building_copy,
                              title: isAr ? '١. شروط وإلتزامات تشغيل الملاعب' : '1. Stadium Operations & Listing Terms',
                              content: isAr
                                  ? 'يلتزم صاحب الملعب بدقة بيانات الملعب والمعلومات المعروضة، وتجهيز الإضاءة والمرافق في المواعيد المحجوزة للاعبين. تضمن المنصة تنظيم الحجوزات وعدم التعارض.'
                                  : 'Stadium owners must guarantee pitch readiness, lighting, and amenities for confirmed slots. VSP manages technical dispatching to prevent conflicts.',
                            ),
                            const SizedBox(height: 12),

                            _buildModalSectionCard(
                              dialogContext,
                              icon: Iconsax.lock_copy,
                              title: isAr ? '٢. سياسة حماية بيانات اللاعبين (PDPL 2020)' : '2. Player Privacy & Data Protection',
                              content: isAr
                                  ? 'وفقاً لقانون حماية البيانات الشخصية المصري (PDPL 2020)، يلتزم المالك بالحفاظ على خصوصية الحاحزين وعدم استغلال بيانات الاتصال الخاصة باللاعبين خارج نطاق تنظيم المباريات.'
                                  : 'Under Egyptian Law PDPL 2020, owners agree to keep player phone numbers strictly confidential and use them only for booking communication.',
                            ),
                            const SizedBox(height: 12),

                            _buildModalSectionCard(
                              dialogContext,
                              icon: Iconsax.wallet_1_copy,
                              title: isAr ? '٣. سياسة التحصيل والعربون المباشر' : '3. Payouts & Deposit Settlement Policy',
                              content: isAr
                                  ? 'يلتزم المالك بتأكيد مبالغ العربون والحجوزات المستلمة عبر (انستا باي أو فودافون كاش أو البنك)، والالتزام بتوفير الملعب للحاحز دون تغيير الأسعار أو الإلغاء المفاجئ.'
                                  : 'Owners must verify and honor direct deposits received via InstaPay, Vodafone Cash, or Bank Transfer, maintaining fixed rates.',
                            ),
                            const SizedBox(height: 12),

                            _buildModalSectionCard(
                              dialogContext,
                              icon: Iconsax.cup_copy,
                              title: isAr ? '٤. نزاهة البطولات والشفافية' : '4. Tournament Integrity & Transparency',
                              content: isAr
                                  ? 'يلتزم المالك بإدارة البطولات والتحديات المعروضة على ملعبه بنزاهة تامة، وتأكيد النتائج وتسليم الجوائز المعلنة للفرق الفائزة دون تأخير.'
                                  : 'Owners hosting tournaments commit to fair refereeing, prompt score confirmation, and timely prize distribution to winning teams.',
                            ),
                          ] else ...[
                            _buildModalSectionCard(
                              dialogContext,
                              icon: Iconsax.document_text_copy,
                              title: isAr ? '١. شروط استخدام منصة VSP' : '1. Terms of VSP Platform Use',
                              content: isAr
                                  ? 'تُعتبر منصة VSP وسيطاً تقنياً لتنظيم وتسهيل حجز ملاعب كرة القدم والتحديات التنافسية بين الفرق. يلتزم الحاحزون والكباتن بالحضور في الموعد المحدد والاحترام المتبادل في الملاعب. أي إلغاء للحجز يخضع لسياسة الملعب المحددة.'
                                  : 'VSP platform acts as a digital intermediary to organize football pitch bookings and team challenges. Players and captains must adhere to scheduled times and mutual respect. Cancellations follow stadium policy.',
                            ),
                            const SizedBox(height: 12),

                            _buildModalSectionCard(
                              dialogContext,
                              icon: Iconsax.lock_copy,
                              title: isAr ? '٢. سياسة حماية البيانات والخصوصية' : '2. Privacy & Data Protection Policy',
                              content: isAr
                                  ? 'وفقاً لقانون حماية البيانات الشخصية المصري (PDPL 2020)، تُجمع البيانات الأساسية (الاسم، رقم الهاتف، والمحافظة) لغرض تنظيم الحجوزات والتواصل بين كباتن الفرق فقط. تلتزم VSP بعدم مشاركة أو بيع أي من بيانات المستخدمين لأطراف خارجية.'
                                  : 'In accordance with the Egyptian Personal Data Protection Law (PDPL 2020), basic data (name, phone, governorate) is processed strictly for match organization. VSP does not sell or share user data with external third parties.',
                            ),
                            const SizedBox(height: 12),

                            _buildModalSectionCard(
                              dialogContext,
                              icon: Iconsax.wallet_1_copy,
                              title: isAr ? '٣. سياسة الرسوم والدفع الإلكتروني' : '3. Payments & Refunds Policy',
                              content: isAr
                                  ? 'تتم معالجة جميع المدفوعات الرقمية بشكل آمن عبر بوابة Paymob المرخصة. تُحسب وتظهر رسوم خدمة المنصة ورسوم معالجة الدفع بوضوح في تفاصيل الحساب قبل إتمام الدفع. لا يتم تخزين بيانات البطاقة المصرفية على خوادمنا. عند إلغاء الحجز المؤهل قبل انتهاء وقت السماح (ساعتين)، يُسترد المبلغ المستحق تلقائياً إلى وسيلة الدفع الأصلية التي استخدمتها.'
                                  : 'All digital payments are processed securely through licensed Paymob gateway. Applicable platform service fees and gateway processing charges are clearly displayed before checkout. Payment credentials are never stored on our servers. Eligible cancellations made before the cutoff window (2 hrs) are automatically refunded to your original payment method.',
                            ),
                            const SizedBox(height: 12),

                            _buildModalSectionCard(
                              dialogContext,
                              icon: Iconsax.cup_copy,
                              title: isAr ? '٤. قواعد الفرق ونظام الترتيب' : '4. Team Rules & Elo Rating System',
                              content: isAr
                                  ? 'يُسمح لكل فريق بتسجيل ما يصل إلى 12 لاعباً، ولكل لاعب الانضمام إلى 3 فرق كحد أقصى. تُعتمد نتائج التحديات تلقائياً بعد 24 ساعة ما لم يُقدَّم اعتراض رسمي.'
                                  : 'Teams can register up to 12 players, and players may join up to 3 teams max. Match results and Elo rating updates become final 24 hours post-match unless an official dispute is raised.',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Action Button Footer
                  const Divider(color: VSPColors.divider, height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        text: buttonText,
                        onPressed: () => Navigator.pop(dialogContext),
                        height: 50,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: VSPColors.accent, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: VSPColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: VSPColors.textSecondary,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
} // end CreateAccountScreen


