import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import 'scale_animated_button.dart';

/// Full-screen onboarding slide presenting hero visual, copy, and auth actions.
class WelcomeOnboardingSlide extends StatelessWidget {
  final int index;
  final double screenHeight;

  const WelcomeOnboardingSlide({
    super.key,
    required this.index,
    required this.screenHeight,
  });

  String _getPlayerButtonText(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic ? "لاعب" : "Player";
  }

  String _getOwnerButtonText(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic ? "صاحب ملعب" : "Owner";
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final String title;
    final String subtitle;
    final String imagePath;

    if (index == 0) {
      title = l10n.welcomePage1Title;
      subtitle = l10n.welcomePage1Subtitle;
      imagePath = "assets/images/welcome_onboarding_3.jpg";
    } else if (index == 1) {
      title = l10n.welcomePage2Title;
      subtitle = l10n.welcomePage2Subtitle;
      imagePath = "assets/images/welcome_onboarding_2.jpg";
    } else {
      title = l10n.welcomePage3Title;
      subtitle = l10n.welcomePage3Subtitle;
      imagePath = "assets/images/welcome_onboarding_1.jpg";
    }

    final double imageHeight = (screenHeight * 0.52).clamp(300.0, 480.0);

    return Column(
      children: [
        // 1. Hero Stadium Header Image with Gradient Blend
        SizedBox(
          height: imageHeight,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                imagePath,
                fit: BoxFit.cover,
              ),
              // Premium Dark Gradient Mask
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x99000000),
                      Colors.transparent,
                      Color(0x8009090B),
                      VSPColors.background,
                    ],
                    stops: [0.0, 0.3, 0.75, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Centered Onboarding Content
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            color: VSPColors.background,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 1),

                if (index == 2) ...[
                  // VSP Logo
                  Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: VSPColors.accent,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: VSPColors.textSecondary,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                if (index == 2) ...[
                  const SizedBox(height: 24),
                  // Dual CTA Action Buttons for Player / Owner
                  Row(
                    children: [
                      // Owner button
                      Expanded(
                        child: ScaleAnimatedButton(
                          onPressed: () {
                            final authProvider =
                                Provider.of<AuthProvider>(context, listen: false);
                            authProvider.setUserType('owner');
                            context.push('/create-account-owner');
                          },
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: VSPColors.surface,
                              borderRadius: BorderRadius.circular(VSPRadius.lg),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _getOwnerButtonText(context),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Player button
                      Expanded(
                        child: ScaleAnimatedButton(
                          onPressed: () {
                            final authProvider =
                                Provider.of<AuthProvider>(context, listen: false);
                            authProvider.setUserType('player');
                            context.push('/create-account-player');
                          },
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: VSPColors.accent,
                              borderRadius: BorderRadius.circular(VSPRadius.lg),
                              boxShadow: [
                                BoxShadow(
                                  color: VSPColors.accent.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _getPlayerButtonText(context),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.alreadyHaveAccount,
                        style: const TextStyle(
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
                          l10n.login,
                          style: const TextStyle(
                            color: VSPColors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
