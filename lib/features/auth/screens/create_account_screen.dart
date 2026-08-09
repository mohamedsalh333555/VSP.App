import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/language_provider.dart';
import 'package:go_router/go_router.dart';

import 'signup_screen.dart';
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
    final languageProvider = Provider.of<LanguageProvider>(context);
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
                    Row(
                      children: [
                        _buildNavCircle(
                          context, 
                          icon: languageProvider.isArabic ? LucideIcons.arrowRight : LucideIcons.arrowLeft,
                          onTap: () => Navigator.pop(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 60),

                    // Greeting Section
                    VSPFadeInItem(
                      index: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontSize: 52,
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

                    // Subtitle - With glass container
                    VSPFadeInItem(
                      index: 2,
                      child: Container(
                        padding: const EdgeInsets.all(VSPSpacing.md),
                        decoration: BoxDecoration(
                          color: VSPColors.glassSurface,
                          borderRadius: BorderRadius.circular(VSPRadius.lg),
                          border: Border.all(color: VSPColors.borderLight),
                        ),
                        child: Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: VSPColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),

                    // Action Buttons
                    VSPFadeInItem(
                      index: 3,
                      child: _NeonButton(
                        text: AppLocalizations.of(context)!.continueWithEmail,
                        onPressed: () {
                          authProvider.setUserType(isUserOwner ? 'owner' : 'player');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SignupScreen(isOwner: isUserOwner),
                            ),
                          );
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
                          if (!kIsWeb && Platform.isIOS) ...[
                            Expanded(
                              child: _SocialButton(
                                height: 56,
                                icon: LucideIcons.apple,
                                onPressed: () async {
                                  authProvider.setUserType(isUserOwner ? 'owner' : 'player');
                                  final success = await authProvider.signInWithApple();
                                  if (context.mounted) {
                                    if (success) {
                                      context.go('/');
                                    } else {
                                      VSPFeedback.showError(context, authProvider.errorMessage ?? 'Apple Sign-In failed');
                                    }
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          
                          // 🟢 زر Google يظهر للجميع
                          Expanded(
                            child: _SocialButton(
                              height: 56,
                              iconWidget: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: const BoxDecoration(
                                      color: VSPColors.textPrimary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'G', 
                                        style: TextStyle(
                                          color: VSPColors.background, 
                                          fontWeight: FontWeight.w900, 
                                          fontSize: 14
                                        )
                                      )
                                    ),
                                  ),
                                  const SizedBox(width: 12),
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
                                  authProvider.setUserType(isUserOwner ? 'owner' : 'player');
                                  final success = await authProvider.signInWithGoogle();
                                  if (context.mounted) {
                                    if (success) {
                                      context.go('/');
                                    } else {
                                      VSPFeedback.showError(context, authProvider.errorMessage ?? 'Google Sign-In failed');
                                    }
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

  Widget _buildNavCircle(BuildContext context, {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: VSPColors.borderLight),
        ),
        child: Icon(icon, color: VSPColors.textPrimary, size: 20),
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: VSPColors.accent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.shieldCheck,
                            color: VSPColors.accent,
                            size: 20,
                          ),
                        ),
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
                          icon: const Icon(LucideIcons.x, color: VSPColors.textSecondary, size: 20),
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
                                const Icon(LucideIcons.info, color: VSPColors.accent, size: 18),
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

                          _buildModalSectionCard(
                            dialogContext,
                            icon: LucideIcons.fileText,
                            title: isAr ? '١. شروط استخدام منصة VSP' : '1. Terms of VSP Platform Use',
                            content: isAr
                                ? 'تُعتبر منصة VSP وسيطاً تقنياً لتنظيم وتسهيل حجز ملاعب كرة القدم والتحديات التنافسية بين الفرق. يلتزم الحاحزون والكباتن بالحضور في الموعد المحدد والاحترام المتبادل في الملاعب. أي إلغاء للحجز يخضع لسياسة الملعب المحددة.'
                                : 'VSP platform acts as a digital intermediary to organize football pitch bookings and team challenges. Players and captains must adhere to scheduled times and mutual respect. Cancellations follow stadium policy.',
                          ),
                          const SizedBox(height: 12),

                          _buildModalSectionCard(
                            dialogContext,
                            icon: LucideIcons.lock,
                            title: isAr ? '٢. سياسة حماية البيانات والخصوصية' : '2. Privacy & Data Protection Policy',
                            content: isAr
                                ? 'وفقاً لقانون حماية البيانات الشخصية المصري (PDPL 2020)، تُجمع البيانات الأساسية (الاسم، رقم الهاتف، والمحافظة) لغرض تنظيم الحجوزات والتواصل بين كباتن الفرق فقط. تلتزم VSP بعدم مشاركة أو بيع أي من بيانات المستخدمين لأطراف خارجية.'
                                : 'In accordance with the Egyptian Personal Data Protection Law (PDPL 2020), basic data (name, phone, governorate) is processed strictly for match organization. VSP does not sell or share user data with external third parties.',
                          ),
                          const SizedBox(height: 12),

                          _buildModalSectionCard(
                            dialogContext,
                            icon: LucideIcons.creditCard,
                            title: isAr ? '٣. سياسة الرسوم والدفع الإلكتروني' : '3. Payments & Refunds Policy',
                            content: isAr
                                ? 'تتم معالجة جميع المدفوعات الرقمية بشكل آمن عبر بوابة Paymob المرخصة. لا يتم تخزين بيانات البطاقة المصرفية على خوادمنا. عند إلغاء الحجز المؤهل قبل انتهاء وقت السماح (ساعتين)، يُسترد المبلغ تلقائياً إلى محفظتك.'
                                : 'All digital payments are securely processed through Paymob. Payment credentials are never stored on our servers. Eligible cancellations made before the cutoff window (2 hrs) are automatically refunded.',
                          ),
                          const SizedBox(height: 12),

                          _buildModalSectionCard(
                            dialogContext,
                            icon: LucideIcons.trophy,
                            title: isAr ? '٤. قواعد الفرق ونظام Elo' : '4. Team Rules & Elo Rating System',
                            content: isAr
                                ? 'يُسمح لكل فريق بتسجيل ما يصل إلى 12 لاعباً، ولكل لاعب الانضمام إلى 3 فرق كحد أقصى. تُعتمد نتائج التحديات تلقائياً بعد 24 ساعة ما لم يُقدَّم اعتراض رسمي.'
                                : 'Teams can register up to 12 players, and players may join up to 3 teams max. Match results and Elo rating updates become final 24 hours post-match unless an official dispute is raised.',
                          ),
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

/// زر أخضر نيون كبير
class _NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _NeonButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      text: text,
      onPressed: onPressed,
      height: 60,
    );
  }
}

/// زر تسجيل دخول اجتماعي
class _SocialButton extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onPressed; // nullable: null = disabled
  final double? height;

  const _SocialButton({
    this.icon,
    this.iconWidget,
    required this.onPressed,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        // No hardcoded width — let the Expanded parent (in the Row) control the width.
        // This prevents RenderFlex overflow on smaller devices.
        width: double.infinity,
        height: height ?? 56,
        decoration: BoxDecoration(
          color: VSPColors.background.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: VSPColors.borderLight,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: iconWidget ??
                Icon(
                  icon,
                  color: VSPColors.textPrimary,
                  size: 24,
                ),
          ),
        ),
      ),
    );
  }
}


