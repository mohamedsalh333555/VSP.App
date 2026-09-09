import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// Exit confirmation modal dialog when abandoning owner onboarding.
class OwnerOnboardingExitDialog {
  const OwnerOnboardingExitDialog._();

  static Future<bool?> show(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: AlertDialog(
          backgroundColor: VSPColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
          title: Text(
            l10n.cancelRegistrationTitle,
            style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Text(
            l10n.cancelRegistrationContent,
            style: const TextStyle(color: VSPColors.textSecondary, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.continueRegistration, style: const TextStyle(color: VSPColors.accent)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(l10n.cancelAndSignOut),
            ),
          ],
        ),
      ),
    );
  }
}
