import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
class CreateAccountScreen extends StatelessWidget {
  final bool isOwner;

  const CreateAccountScreen({
    super.key,
    this.isOwner = false, // Default to player to be safe
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool isUserOwner = isOwner;

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
                                  style: const TextStyle(
                                    color: VSPColors.accent,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                TextSpan(text: AppLocalizations.of(context)!.and),
                                TextSpan(
                                  text: AppLocalizations.of(context)!.privacyPolicy,
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

