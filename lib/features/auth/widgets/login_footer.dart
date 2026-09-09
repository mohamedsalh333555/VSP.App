import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../l10n/app_localizations.dart';

/// Footer for LoginScreen with navigation to signup.
class LoginFooter extends StatelessWidget {
  const LoginFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppLocalizations.of(context)!.dontHaveAccount,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: VSPColors.textSecondary,
                fontSize: 14,
              ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            context.go('/welcome');
          },
          child: Text(
            AppLocalizations.of(context)!.signUp,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: VSPColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
          ),
        ),
      ],
    );
  }
}
