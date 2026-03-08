import '../../../core/ui/tokens/vsp_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              VSPColors.background,
              VSPColors.accent.withValues(alpha: 0.1),
              VSPColors.background,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // Success Icon with subtle breath animation
                    _buildAnimatedIcon(),

                    const SizedBox(height: 40),

                    // Success Title
                    Text(
                      languageProvider.getText(AppStrings.accountCreated),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Welcome Message
                    Text(
                      languageProvider.getText(AppStrings.welcomeMessage),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: VSPColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    // Step Indicator
                    Text(
                      '4/4',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Get Started Button
                    VSPAnimatedButton(
                      text: languageProvider.getText(AppStrings.getStarted),
                      onPressed: () => _handleGetStarted(context),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
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
          color: VSPColors.accent.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: VSPColors.accent.withValues(alpha: 0.2),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: const Icon(
          Icons.check_circle_outline,
          size: 80,
          color: VSPColors.accent,
        ),
      ),
    );
  }
}

