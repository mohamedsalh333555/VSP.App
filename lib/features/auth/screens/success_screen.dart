import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../owner/screens/facility_onboarding_screen.dart';
import '../../player/screens/player_home_screen.dart';
import '../../../shared/widgets/vsp_animated_button.dart';

/// شاشة نجاح التسجيل - الخطوة 4
class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _breathController;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late Animation<double> _breath;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       duration: const Duration(milliseconds: 1000),
       vsync: this,
    );

    _breathController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack)),
    );

    _breath = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _breathController.dispose();
    super.dispose();
  }

  void _handleGetStarted(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.isOwner) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const FacilityOnboardingScreen(),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const PlayerHomeScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

      return Scaffold(
        backgroundColor: VSPColors.background,
        body: Stack(
          children: [
            // 1. Immersive Glows
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VSPColors.accent.withValues(alpha: 0.08),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const Spacer(flex: 3),

                        // Success Celebration Header
                        _buildAnimatedIcon(),

                        const SizedBox(height: 48),

                        // Success Title - High Impact
                        Text(
                          languageProvider.getText(AppStrings.accountCreated).toUpperCase(),
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 44,
                            height: 0.9,
                            letterSpacing: -1,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        // Welcome Message
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            languageProvider.getText(AppStrings.welcomeMessage),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: VSPColors.textSecondary,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const Spacer(flex: 4),

                        // Get Started Action with Glassy footer
                         Container(
                          padding: const EdgeInsets.all(VSPSpacing.md),
                          decoration: BoxDecoration(
                            color: VSPColors.surface.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(VSPRadius.xl),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              VSPAnimatedButton(
                                text: languageProvider.getText(AppStrings.getStarted),
                                onPressed: () => _handleGetStarted(context),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildAnimatedIcon() {
    return ScaleTransition(
      scale: _breath,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: VSPColors.accent.withValues(alpha: 0.15),
          border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4), width: 2),
        ),
        child: Icon(Iconsax.tick_circle_copy,
          size: 64,
          color: VSPColors.accent,
        ),
      ),
    );
  }
}
