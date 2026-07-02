import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isOwner = auth.isOwner;

    List<PageViewModel> pages = isOwner 
      ? [
          PageViewModel(
            title: "Welcome, Stadium Owner! 🏟️",
            body: "VSP helps you manage your stadium effortlessly. Start by adding your facility details.",
            image: _buildImage('assets/images/owner_onboarding_1.png'),
            decoration: _getPageDecoration(),
          ),
          PageViewModel(
            title: "Verified Ledger System 📑",
            body: "Track all bookings and payments through our transparent ledger system. No more double bookings.",
            image: _buildImage('assets/images/owner_onboarding_2.png'),
            decoration: _getPageDecoration(),
          ),
          PageViewModel(
            title: "Identity Verification 🛡️",
            body: "Complete your documentation to get the 'Verified Owner' badge and attract more players.",
            image: _buildImage('assets/images/owner_onboarding_3.png'),
            decoration: _getPageDecoration(),
          ),
        ]
      : [
          PageViewModel(
            title: "The Ultimate Sports ID ⚽",
            body: "Create your player card, track your Elo ranking, and feel like a professional athlete.",
            image: _buildImage('assets/images/player_onboarding_1.png'),
            decoration: _getPageDecoration(),
          ),
          PageViewModel(
            title: "Compete & Rank Up 🏆",
            body: "Join public matches, win challenges, and climb the leaderboard to reach 'Legend' status.",
            image: _buildImage('assets/images/player_onboarding_2.png'),
            decoration: _getPageDecoration(),
          ),
          PageViewModel(
            title: "Smart Discovery 📍",
            body: "Find stadiums near you and join the community. Your next match is just a tap away.",
            image: _buildImage('assets/images/player_onboarding_3.png'),
            decoration: _getPageDecoration(),
          ),
        ];

    return IntroductionScreen(
      pages: pages,
      onDone: () async {
        await auth.completeOnboarding();
        if (context.mounted) {
          context.go('/');
        }
      },
      showSkipButton: true,
      skip: const Text("Skip", style: TextStyle(color: VSPColors.textSecondary)),
      next: const Icon(Icons.arrow_forward, color: VSPColors.accent),
      done: const Text("Get Started", style: TextStyle(fontWeight: FontWeight.w600, color: VSPColors.accent)),
      dotsDecorator: DotsDecorator(
        size: const Size(10.0, 10.0),
        activeSize: const Size(22.0, 10.0),
        activeColor: VSPColors.accent,
        color: VSPColors.textSecondary.withValues(alpha: 0.3),
        spacing: const EdgeInsets.symmetric(horizontal: 3.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.0)
        ),
      ),
      globalBackgroundColor: VSPColors.background,
    );
  }

  Widget _buildImage(String assetName) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(VSPSpacing.xl),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.sports_soccer, size: 100, color: VSPColors.accent), // Placeholder icons for now
      ),
    );
  }

  PageDecoration _getPageDecoration() {
    return const PageDecoration(
      titleTextStyle: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: Colors.white),
      bodyTextStyle: TextStyle(fontSize: 16.0, color: VSPColors.textSecondary),
      bodyPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: VSPColors.background,
      imagePadding: EdgeInsets.zero,
    );
  }
}
