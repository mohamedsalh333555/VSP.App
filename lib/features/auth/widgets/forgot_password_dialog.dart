import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/custom_text_field.dart';

/// Modal dialog for requesting a password reset email.
class ForgotPasswordDialog {
  const ForgotPasswordDialog._();

  static Future<void> show(BuildContext context) {
    final resetEmailController = TextEditingController();
    return showDialog(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: VSPColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VSPRadius.lg),
              ),
              title: Text(
                AppLocalizations.of(context)!.forgotPassword,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context)!.forgotPasswordSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: VSPColors.textSecondary,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    hintText: AppLocalizations.of(context)!.emailAddress,
                    prefixIcon: Iconsax.sms_copy,
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          AppLocalizations.of(context)!.cancel,
                          style: const TextStyle(color: VSPColors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                final email = resetEmailController.text.trim();
                                if (email.isEmpty || !email.contains('@')) {
                                  VSPFeedback.showError(context, AppLocalizations.of(context)!.invalidEmail);
                                  return;
                                }
                                setDialogState(() => isLoading = true);
                                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                final success = await authProvider.resetPassword(email);
                                if (!dialogContext.mounted) return;
                                Navigator.pop(dialogContext);
                                if (context.mounted) {
                                  if (success) {
                                    VSPFeedback.showSuccess(context, AppLocalizations.of(context)!.resetPasswordSuccess);
                                  } else {
                                    VSPFeedback.showError(
                                      context,
                                      authProvider.errorMessage ?? AppLocalizations.of(context)!.resetPasswordError,
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(VSPRadius.md),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : Text(
                                AppLocalizations.of(context)!.submit,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    ).then((_) => resetEmailController.dispose());
  }
}
