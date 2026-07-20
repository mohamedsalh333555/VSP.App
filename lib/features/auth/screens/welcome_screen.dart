import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

import 'create_account_screen.dart';
import 'login_screen.dart';

/// Welcome Screen - Initial landing page with clean layout and interactive 3-page onboarding welcome flow.
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
      imagePath = "assets/images/welcome_onboarding_3.jpg"; // Kicking ball
    } else if (index == 1) {
      title = AppLocalizations.of(context)!.welcomePage2Title;
      subtitle = AppLocalizations.of(context)!.welcomePage2Subtitle;
      imagePath = "assets/images/welcome_onboarding_2.jpg"; // Stadium
    } else {
      title = AppLocalizations.of(context)!.welcomePage3Title;
      subtitle = AppLocalizations.of(context)!.welcomePage3Subtitle;
      imagePath = "assets/images/welcome_onboarding_1.jpg"; // Goal net
    }

    return Column(
      children: [
        // Top Image (58% height of the screen)
        SizedBox(
          height: screenHeight * 0.58,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                ),
              ),
              // Smooth gradient mask blending the image into the solid background
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x80121212),
                        VSPColors.background,
                      ],
                      stops: [0.35, 0.75, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom content starting below the image
        Expanded(
          child: Container(
            color: VSPColors.background,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (index == 2) ...[
                      // VSP Logo centered above Page 3 content
                      Hero(
                        tag: 'app_logo',
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 75,
                          height: 75,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      // Spacer to push titles down for Pages 1 & 2
                      const SizedBox(height: 32),
                    ],

                    // Page Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: VSPColors.accent,
                        height: 1.1,
                        letterSpacing: -0.5,
                        fontFamilyFallback: ['Tajawal', 'sans-serif'],
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    // Page Subtitle
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: VSPColors.textSecondary,
                        height: 1.5,
                        fontFamilyFallback: ['Tajawal', 'sans-serif'],
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (index == 2) ...[
                      const SizedBox(height: 24),
                      // Dual Expanded Buttons for Player / Owner
                      Row(
                        children: [
                          // Owner button (left)
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
                                height: 56,
                                decoration: BoxDecoration(
                                  color: VSPColors.surface,
                                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                ),
                                child: Center(
                                  child: Text(
                                    getOwnerButtonText(context),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      fontFamilyFallback: ['Tajawal', 'sans-serif'],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Player button (right)
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
                                height: 56,
                                decoration: BoxDecoration(
                                  color: VSPColors.accent,
                                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                                  boxShadow: [
                                    BoxShadow(
                                      color: VSPColors.accent.withValues(alpha: 0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    getPlayerButtonText(context),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      fontFamilyFallback: ['Tajawal', 'sans-serif'],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Login Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.alreadyHaveAccount,
                            style: const TextStyle(
                              color: VSPColors.textSecondary,
                              fontSize: 14.5,
                              fontFamilyFallback: ['Tajawal', 'sans-serif'],
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
                                fontSize: 14.5,
                                fontFamilyFallback: ['Tajawal', 'sans-serif'],
                            ),
                          ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
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
          width: isActive ? 24.0 : 8.0,
          decoration: BoxDecoration(
            color: isActive ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.4),
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
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: VSPColors.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: VSPColors.accent.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          LucideIcons.arrowRight,
          color: Colors.black,
          size: 24,
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
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.globe, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      langProvider.isArabic 
                          ? AppLocalizations.of(context)!.english 
                          : AppLocalizations.of(context)!.arabic,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
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

            // 2. Fixed Top Navigation Bar (Language Switcher & Back Arrow)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Arrow Button (only on pages 2 & 3)
                  _currentPage > 0
                      ? ScaleAnimatedButton(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Icon(
                              Localizations.localeOf(context).languageCode == 'ar'
                                  ? LucideIcons.arrowRight
                                  : LucideIcons.arrowLeft,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        )
                      : const SizedBox(width: 36),

                  // Language switch button
                  _buildLanguageSwitcher(),
                ],
              ),
            ),

            // 3. Fixed Bottom indicators and FAB (only visible on Pages 1 & 2)
            if (_currentPage < 2)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 24,
                right: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPageIndicator(),
                    _buildNextFAB(),
                  ],
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


