import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/social_auth_button.dart';

/// Row of social authentication buttons (Apple & Google) with role persistence.
class SocialAuthButtonsRow extends StatelessWidget {
  final bool isOwner;

  const SocialAuthButtonsRow({
    super.key,
    required this.isOwner,
  });

  Future<void> _handleOAuth(BuildContext context, {required bool isApple}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final role = isOwner ? 'owner' : 'player';

    authProvider.setUserType(role);
    await SecureStorageService.writeSecure('pending_oauth_role', role);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_oauth_role', role);
    await prefs.setBool('pending_oauth_is_login_only', false);

    final bool success = isApple
        ? await authProvider.signInWithApple(isLoginOnly: false)
        : await authProvider.signInWithGoogle(isLoginOnly: false);

    if (context.mounted && !success) {
      final defaultMsg = isApple ? 'Apple Sign-In failed' : 'Google Sign-In failed';
      VSPFeedback.showError(context, authProvider.errorMessage ?? defaultMsg);
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
              onPressed: () => _handleOAuth(context, isApple: true),
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
            onPressed: () => _handleOAuth(context, isApple: false),
          ),
        ),
      ],
    );
  }
}
