import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/utils/email_address_validator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../services/password_reset_privacy_message.dart';

/// Public password recovery never reveals whether a submitted email exists.
class ForgotPasswordDialog {
  const ForgotPasswordDialog._();

  static Future<void> show(BuildContext context) => showDialog<void>(
        context: context,
        useSafeArea: true,
        builder: (_) => _ForgotPasswordDialogContent(hostContext: context),
      );
}

/// The dialog owns its editing controller until its widget is actually
/// unmounted. Disposing when showDialog's Future completes can occur during
/// the exit animation, while TextFormField still listens to the controller.
class _ForgotPasswordDialogContent extends StatefulWidget {
  const _ForgotPasswordDialogContent({required this.hostContext});

  final BuildContext hostContext;

  @override
  State<_ForgotPasswordDialogContent> createState() =>
      _ForgotPasswordDialogContentState();
}

class _ForgotPasswordDialogContentState
    extends State<_ForgotPasswordDialogContent> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    if (!EmailAddressValidator.isValid(email)) {
      VSPFeedback.showError(context, l10n.invalidEmail);
      return;
    }

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    try {
      // Both successful and unsuccessful requests show exactly the same
      // generic acknowledgement. Do not reveal raw provider errors.
      await auth.resetPassword(email);
    } catch (_) {
      // Do not expose email existence or transport errors on this public UI.
    }
    if (!mounted) return;

    final hostContext = widget.hostContext;
    Navigator.of(context).pop();
    // The dialog's own context is removed after pop; use the originating
    // screen's context to display the neutral acknowledgement.
    if (!hostContext.mounted) return;
    final isArabic = Localizations.localeOf(hostContext).languageCode == 'ar';
    VSPFeedback.showSuccess(
      hostContext,
      PasswordResetPrivacyMessage.acknowledgement(isArabic: isArabic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      scrollable: true,
      backgroundColor: VSPColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VSPRadius.lg),
      ),
      title: Text(
        l10n.forgotPassword,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.forgotPasswordSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: VSPColors.textSecondary,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            hintText: l10n.emailAddress,
            prefixIcon: Iconsax.sms_copy,
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 12,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                child: Text(
                  l10n.cancel,
                  style: const TextStyle(color: VSPColors.textSecondary),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: VSPColors.accent,
                  foregroundColor: VSPColors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: VSPColors.black,
                        ),
                      )
                    : Text(
                        l10n.submit,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
