import '../../../core/ui/tokens/vsp_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/navigation/root_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool navigate;
  const SplashScreen({super.key, this.navigate = true});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Set status bar to dark
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: VSPColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    // Initialize fade animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000), // Slightly faster
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: VSPColors.background,
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Image.asset(
              'assets/images/logo.png',
              width: 220.0,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  'VSP',
                  style: TextStyle(
                    color: VSPColors.accent,
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

