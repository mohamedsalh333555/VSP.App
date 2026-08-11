import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

import 'create_account_screen.dart';
import 'login_screen.dart';

/// Welcome Screen - State-of-the-Art Glassmorphic Onboarding Experience.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final hasError = auth.errorMessage != null && auth.errorMessage!.isNotEmpty;
      final hasStaleData = auth.userType != null || auth.errorMessage != null || auth.email.isNotEmpty;

      if (hasError) {
        VSPFeedback.showError(context, auth.errorMessage!);
      }

      if (hasStaleData) {
        auth.reset();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String getPlayerButtonText(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic ? "لاعب" : "Player";
  }

  String getOwnerButtonText(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic ? "صاحب ملعب" : "Owner";
  }

  Widget _buildPage(int index, double screenHeight) {
    String title = "";
    String subtitle = "";
    String imagePath = "";

    if (index == 0) {
      title = AppLocalizations.of(context)!.welcomePage1Title;
      subtitle = AppLocalizations.of(context)!.welcomePage1Subtitle;
      imagePath = "assets/images/welcome_onboarding_3.jpg";
    } else if (index == 1) {
      title = AppLocalizations.of(context)!.welcomePage2Title;
      subtitle = AppLocalizations.of(context)!.welcomePage2Subtitle;
      imagePath = "assets/images/welcome_onboarding_2.jpg";
    } else {
      title = AppLocalizations.of(context)!.welcomePage3Title;
      subtitle = AppLocalizations.of(context)!.welcomePage3Subtitle;
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

        // 2. Perfectly Centered Onboarding Content (Zero Empty Voids)
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
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: VSPColors.glassSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: VSPColors.glassBorder),
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 54,
                        height: 54,
                      ),
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
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            authProvider.setUserType('owner');
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreateAccountScreen(isOwner: true),
                              ),
                            );
                          },
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: VSPColors.surface,
                              borderRadius: BorderRadius.circular(VSPRadius.lg),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: Center(
                              child: Text(
                                getOwnerButtonText(context),
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
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            authProvider.setUserType('player');
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreateAccountScreen(isOwner: false),
                              ),
                            );
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
                                getPlayerButtonText(context),
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
                        AppLocalizations.of(context)!.alreadyHaveAccount,
                        style: const TextStyle(
                          color: VSPColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: Text(
                          AppLocalizations.of(context)!.login,
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

  Widget _buildPageIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final isActive = _currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          height: 6,
          width: isActive ? 28.0 : 8.0,
          decoration: BoxDecoration(
            color: isActive ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildNextFAB() {
    return ScaleAnimatedButton(
      onPressed: () {
        if (_currentPage < 2) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: VSPColors.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: VSPColors.accent.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Localizations.localeOf(context).languageCode == 'ar' ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_3_copy,
          color: Colors.black,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildLanguageSwitcher() {
    return Consumer<LanguageProvider>(
      builder: (context, langProvider, _) {
        return ScaleAnimatedButton(
          onPressed: () {
            langProvider.changeLanguage(langProvider.isArabic ? 'en' : 'ar');
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(VSPRadius.full),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: VSPColors.glassSurface,
                  borderRadius: BorderRadius.circular(VSPRadius.full),
                  border: Border.all(color: VSPColors.glassBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.global_copy, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      langProvider.isArabic 
                          ? AppLocalizations.of(context)!.english 
                          : AppLocalizations.of(context)!.arabic,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: VSPColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: VSPColors.background,
        body: Stack(
          children: [
            // 1. PageView for sliding onboarding content
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: [
                _buildPage(0, screenHeight),
                _buildPage(1, screenHeight),
                _buildPage(2, screenHeight),
              ],
            ),

            // 2. Fixed Top Safe Bar (Language Switcher & Glass Back Arrow)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Glass Back Arrow (Only visible when page > 0)
                      _currentPage > 0
                          ? ScaleAnimatedButton(
                              onPressed: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(VSPRadius.full),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: VSPColors.glassSurface,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: VSPColors.glassBorder),
                                    ),
                                    child: Icon(
                                      Localizations.localeOf(context).languageCode == 'ar'
                                          ? Iconsax.arrow_right_3_copy
                                          : Iconsax.arrow_left_2_copy,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox(width: 40),

                      // Language switch button
                      _buildLanguageSwitcher(),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Fixed Bottom indicators & FAB (Only on Pages 0 & 1)
            if (_currentPage < 2)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPageIndicator(),
                        _buildNextFAB(),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A reusable micro-animated button wrapper for scaling touch feedback
class ScaleAnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const ScaleAnimatedButton({
    super.key,
    required this.child,
    required this.onPressed,
  });

  @override
  State<ScaleAnimatedButton> createState() => _ScaleAnimatedButtonState();
}

class _ScaleAnimatedButtonState extends State<ScaleAnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  bool _isDebouncing = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
      lowerBound: 0.94,
      upperBound: 1.0,
    )..value = 1.0;

    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (mounted && !_isDebouncing) _controller.reverse();
      },
      onTapUp: (_) {
        if (mounted && !_isDebouncing) _controller.forward();
      },
      onTapCancel: () {
        if (mounted && !_isDebouncing) _controller.forward();
      },
      onTap: () {
        if (_isDebouncing) return;
        setState(() => _isDebouncing = true);
        widget.onPressed();
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _isDebouncing = false);
        });
      },
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
