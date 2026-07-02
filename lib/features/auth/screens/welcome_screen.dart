import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/language_provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

import 'create_account_screen.dart';
import 'login_screen.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../shared/widgets/vsp_animated_button.dart';


/// Welcome Screen - Initial landing page
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
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
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

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
        body: Stack(
          children: [
            // 1. Dynamic Background Depth
            Positioned(
              top: -150,
              left: -50,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      VSPColors.accent.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                    stops: const [0.2, 1.0],
                  ),
                ),
              ),
            ),
            
            // 2. Animated Background Lines or shapes (Static for now but styled)
             Positioned(
              bottom: 40,
              right: -20,
              child: Opacity(
                opacity: 0.1,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 300,
                  height: 300,
                  color: VSPColors.accent,
                ),
              ),
            ),

            // 🟢 زر تبديل اللغة (تمت إضافته هنا)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 24,
              child: Consumer<LanguageProvider>(
                builder: (context, langProvider, _) {
                  return GestureDetector(
                    onTap: () {
                      // التبديل بضغطة واحدة
                      langProvider.changeLanguage(langProvider.isArabic ? 'en' : 'ar');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: VSPColors.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: VSPColors.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.language, size: 16, color: VSPColors.accent),
                          const SizedBox(width: 8),
                          Text(
                            langProvider.isArabic ? AppLocalizations.of(context)!.english : AppLocalizations.of(context)!.arabic,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              ),
            ),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 60),

                              // Brand Identity
                              GestureDetector(
                                // 🔒 DEV ONLY: Long-press to seed database.
                                // Completely disabled in production (AppConfig.demoMode = false).
                                onLongPress: null,
                                child: Hero(
                                  tag: 'app_logo',
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    width: 120,
                                    height: 120,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Slogan / Primary Title
                              Text(
                                AppLocalizations.of(context)!.unleashChampion,
                                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  fontSize: 48,
                                  height: 0.9,
                                  letterSpacing: -1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 16),

                              Text(
                                  AppLocalizations.of(context)!.premierPlatform,
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: VSPColors.accent,
                                    letterSpacing: 2.0,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 48),

                              // Action Section
                              Container(
                                padding: const EdgeInsets.all(VSPSpacing.md),
                                decoration: BoxDecoration(
                                  color: VSPColors.surface.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(VSPRadius.xl),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      AppLocalizations.of(context)!.readyToJoin,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: VSPColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    VSPAnimatedButton(
                                      text: AppLocalizations.of(context)!.iAmPlayer,
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
                                    const SizedBox(height: 12),
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
                                          side: BorderSide(color: VSPColors.textSecondary.withValues(alpha: 0.2)),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(VSPRadius.lg),
                                          ),
                                        ),
                                        child: Text(
                                          AppLocalizations.of(context)!.iAmOwner,
                                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: VSPColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: VSPSpacing.xl),

                              // Footer
                              Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        AppLocalizations.of(context)!.alreadyHaveAccount,
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
                                          AppLocalizations.of(context)!.login,
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
                                              AppLocalizations.of(context)!.signOutCurrentAccount,
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
                },
              ),
            ),
      ],
    ),
  ),
);
  }
}
