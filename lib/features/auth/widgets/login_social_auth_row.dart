import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/social_auth_button.dart';

/// Row of social authentication buttons tailored for login with loading callbacks and feedback.
class LoginSocialAuthRow extends StatelessWidget {
  final bool isLoading;
  final ValueChanged<bool> onLoadingChanged;

  const LoginSocialAuthRow({
    super.key,
    required this.isLoading,
    required this.onLoadingChanged,
  });

  Future<void> _handleAppleSignIn(BuildContext context) async {
    HapticFeedback.mediumImpact();
    onLoadingChanged(true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signInWithApple(isLoginOnly: true);

    if (!context.mounted) return;
    onLoadingChanged(false);

    if (success) {
      HapticFeedback.lightImpact();
      context.go('/');
    } else {
      HapticFeedback.vibrate();
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      VSPFeedback.showError(
        context,
        authProvider.errorMessage ?? (isAr ? 'فشل تسجيل الدخول عبر Apple' : 'Apple Sign-In failed'),
      );
    }
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    HapticFeedback.mediumImpact();
    onLoadingChanged(true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signInWithGoogle(isLoginOnly: true);

    if (!context.mounted) return;
    onLoadingChanged(false);

    if (success) {
      HapticFeedback.lightImpact();
      // GoRouter handles declarative navigation to /, /verify-email, /onboarding, or /owner
    } else {
      HapticFeedback.vibrate();
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      VSPFeedback.showError(
        context,
        authProvider.errorMessage ?? (isAr ? 'فشل تسجيل الدخول عبر Google' : 'Google Sign-In failed'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
          Expanded(
            child: SocialAuthButton(
              height: 56,
              iconWidget: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/apple_logo.png',
                    width: 20,
                    height: 20,
                    color: VSPColors.textPrimary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Apple',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: VSPColors.textPrimary,
                        ),
                  ),
                ],
              ),
              onPressed: isLoading ? null : () => _handleAppleSignIn(context),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: SocialAuthButton(
            height: 56,
            iconWidget: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/google_logo.png',
                  width: 22,
                  height: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  AppLocalizations.of(context)!.continueWithGoogle,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: VSPColors.textPrimary,
                      ),
                ),
              ],
            ),
            onPressed: isLoading ? null : () => _handleGoogleSignIn(context),
          ),
        ),
      ],
    );
  }
}
