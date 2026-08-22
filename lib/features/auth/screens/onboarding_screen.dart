import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

@Deprecated('Use PlayerOnboardingScreen or OwnerOnboardingScreen')
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: VSPColors.background,
      body: Center(child: Text('Onboarding', style: TextStyle(color: Colors.white))),
    );
  }
}
