import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../services/password_reset_privacy_message.dart';

/// Modal dialog for requesting a password reset email.
class ForgotPasswordDialog {
  const ForgotPasswordDialog._();

  static Future<void> show(BuildContext context) {
    final hostContext = context;
    final resetEmailController = TextEditingController();
    return showDialog(
      context: context,
      useSafeArea: true,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
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
                        style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
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
                                try {
                                  // Success and failure must show the same
                                  // acknowledgement to prevent email enumeration.
                                  await authProvider.resetPassword(email);
                                } catch (_) {
                                  // Do not expose provider errors or account
                                  // existence through public recovery feedback.
                                }
                                if (!dialogContext.mounted) return;
                                Navigator.pop(dialogContext);
                                // The dialog's own BuildContext is disposed
                                // during pop. Show feedback on the host screen.
                                if (hostContext.mounted) {
                                  final isArabic = Localizations.localeOf(hostContext).languageCode == 'ar';
                                  VSPFeedback.showSuccess(
                                    hostContext,
                                    PasswordResetPrivacyMessage.acknowledgement(isArabic: isArabic),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: VSPColors.accent,
                          foregroundColor: VSPColors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(VSPRadius.md),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.black),
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
