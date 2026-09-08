import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../widgets/welcome/scale_animated_button.dart';
import '../widgets/welcome/welcome_language_button.dart';
import '../widgets/welcome/welcome_onboarding_slide.dart';

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

      if (hasError) {
        VSPFeedback.showError(context, auth.errorMessage!);
        auth.clearError(); // تفريغ الخطأ فور عرضه لمنع التكرار
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
          Localizations.localeOf(context).languageCode == 'ar'
              ? Iconsax.arrow_left_2_copy
              : Iconsax.arrow_right_3_copy,
          color: Colors.black,
          size: 20,
        ),
      ),
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
                WelcomeOnboardingSlide(index: 0, screenHeight: screenHeight),
                WelcomeOnboardingSlide(index: 1, screenHeight: screenHeight),
                WelcomeOnboardingSlide(index: 2, screenHeight: screenHeight),
              ],
            ),

            // 2. Fixed Top Safe Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 24.0, right: 24.0, top: 12.0, bottom: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Glass Back Arrow (Only visible when page > 0)
                      _currentPage > 0
                          ? VSPBackButton(
                              onTap: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                            )
                          : const SizedBox(width: 38, height: 38),

                      // Language switch button
                      const WelcomeLanguageButton(),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 16.0),
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
