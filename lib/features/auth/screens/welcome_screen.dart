import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';

import '../../../core/utils/data_migration.dart';
import 'create_account_screen.dart';
import 'login_screen.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_button.dart';
import '../../../shared/widgets/vsp_animated_button.dart';
import '../../../core/utils/vsp_feedback.dart';


/// Welcome Screen - Initial landing page
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Clear stale userType to prevent auto-skip issues
    WidgetsBinding.instance.addPostFrameCallback((_) => authProvider.reset());

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: VSPColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: VSPColors.background,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: SafeArea(
          bottom: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.lg),
            child: Column(
              children: [
                const SizedBox(height: VSPSpacing.xxl), // Space where logo/top once was

                // Logo with soft diffused glow (Increased Blur) and Secret Migration Trigger
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 280, // Slightly larger for spread
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: VSPColors.accent.withValues(alpha: 0.08), // Subtle
                            blurRadius: 120, // Increased for more diffusion
                            spreadRadius: 40,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onLongPress: () async {
                        // Secret Trigger for Data Migration
                        VSPFeedback.showSuccess(context, 'Starting Data Migration...');
                        await DataMigration().seedDatabase();
                        if (context.mounted) {
                          VSPFeedback.showSuccess(context, 'Data Migration Completed!');
                        }
                      },
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 180,
                        height: 180,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Text(
                              'VSP',
                              style: TextStyle(
                                color: VSPColors.accent,
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: VSPSpacing.xxl),

                // Welcome Title - English Only
                Text(
                  'Welcome to VSP',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 38, // Keep primary impact size
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: VSPSpacing.md),

                // Subtitle - English, Medium weight, Clean White
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                  child: Text(
                    'Book your pitch easily and join teams',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: VSPColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(flex: 2),

                // User Type Buttons
                Column(
                  children: [
                      // Player Button
                      VSPAnimatedButton(
                        text: 'I am a Player',
                        onPressed: () {
                          authProvider.setUserType('player');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateAccountScreen(isOwner: false),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: VSPSpacing.md),
                      // Owner Button
                      SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            authProvider.setUserType('owner');
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreateAccountScreen(isOwner: true),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: VSPColors.textPrimary,
                            side: const BorderSide(color: VSPColors.accent, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(VSPRadius.lg),
                            ),
                          ),
                          child: Text(
                            'I am Stadium Owner',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: VSPSpacing.xl),

                // Footer - English
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: VSPColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: VSPSpacing.sm),
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
                            'Login',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: VSPColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Stuck User Escape Hatch
                    Consumer<AuthProvider>(
                      builder: (context, auth, child) {
                        if (auth.isAuthenticated) {
                          return Padding(
                            padding: const EdgeInsets.only(top: VSPSpacing.sm),
                            child: TextButton(
                              onPressed: () async {
                                await auth.signOut();
                                if (context.mounted) {
                                  VSPFeedback.showSuccess(context, 'Signed out successfully');
                                }
                              },
                              child: Text(
                                'Sign out of current account',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: VSPColors.textSecondary.withValues(alpha: 0.38),
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: VSPSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
