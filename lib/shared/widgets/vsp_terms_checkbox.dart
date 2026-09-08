import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../dialogs/vsp_terms_and_privacy_modal.dart';

/// مربع اختيار الموافقة على الشروط وسياسة الخصوصية مع إمكانية فتح التفاصيل
class VSPTermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTermsTap;
  final bool isOwner;

  const VSPTermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.onTermsTap,
    this.isOwner = false,
  });

  static void showTermsModal(BuildContext context, {bool isOwner = false}) {
    VSPTermsAndPrivacyModal.show(context, isOwner: isOwner);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(!value);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? VSPColors.accent : VSPColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value ? VSPColors.accent : VSPColors.borderLight,
                  width: 1.5,
                ),
              ),
              child: value
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.black,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(!value);
              },
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: VSPColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                  children: [
                    TextSpan(text: l10n.iAgreeTo),
                    TextSpan(
                      text: l10n.termsOfService,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          if (onTermsTap != null) {
                            onTermsTap!();
                          } else {
                            showTermsModal(context, isOwner: isOwner);
                          }
                        },
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    TextSpan(text: l10n.and),
                    TextSpan(
                      text: l10n.privacyPolicy,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          if (onTermsTap != null) {
                            onTermsTap!();
                          } else {
                            showTermsModal(context, isOwner: isOwner);
                          }
                        },
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
