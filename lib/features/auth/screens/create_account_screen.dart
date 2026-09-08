import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/dialogs/vsp_terms_and_privacy_modal.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_auth_header.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../widgets/social_auth_buttons_row.dart';

/// شاشة إنشاء حساب جديد - تظهر بعد اختيار الدور
class CreateAccountScreen extends StatefulWidget {
  final bool isOwner;

  const CreateAccountScreen({
    super.key,
    this.isOwner = false,
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
    VSPTermsAndPrivacyModal.show(context, isOwner: widget.isOwner);
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isUserOwner = widget.isOwner;

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
            // Subtle Background Glow
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

            // Main Content
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
                    const VSPAuthHeader(showLogo: true),

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

                    // Subtitle
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

                    // Action Button: Continue with email
                    VSPFadeInItem(
                      index: 3,
                      child: PrimaryButton(
                        text: AppLocalizations.of(context)!.continueWithEmail,
                        height: 60,
                        onPressed: () {
                          context.push(isUserOwner ? '/signup-owner' : '/signup-player');
                        },
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Divider Or
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

                    const SizedBox(height: 28),

                    // Social Sign-In Buttons (Google & Apple)
                    VSPFadeInItem(
                      index: 5,
                      child: SocialAuthButtonsRow(isOwner: isUserOwner),
                    ),

                    const SizedBox(height: 32),

                    // Already have an account? Sign in
                    VSPFadeInItem(
                      index: 6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.alreadyHaveAccount,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: VSPColors.textSecondary,
                                  fontSize: 14,
                                ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              context.push('/login');
                            },
                            child: Text(
                              AppLocalizations.of(context)!.login,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: VSPColors.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Footer Links
                    VSPFadeInItem(
                      index: 7,
                      child: Center(
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: VSPColors.textSecondary.withValues(alpha: 0.75),
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
}
