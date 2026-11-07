import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../dialogs/vsp_terms_and_privacy_modal.dart';

/// مربع اختيار الموافقة على الشروط وسياسة الخصوصية مع إمكانية فتح التفاصيل
class VSPTermsCheckbox extends StatefulWidget {
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
  State<VSPTermsCheckbox> createState() => _VSPTermsCheckboxState();
}

class _VSPTermsCheckboxState extends State<VSPTermsCheckbox> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = _openTerms;
    _privacyRecognizer = TapGestureRecognizer()..onTap = _openTerms;
  }

  void _openTerms() {
    if (widget.onTermsTap != null) {
      widget.onTermsTap!();
    } else {
      VSPTermsCheckbox.showTermsModal(context, isOwner: widget.isOwner);
    }
  }

  void _toggleValue() {
    HapticFeedback.selectionClick();
    widget.onChanged(!widget.value);
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context)!;
    final value = widget.value;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          label: isAr ? 'الموافقة على الشروط والأحكام' : 'Agree to Terms and Conditions',
          button: true,
          checked: value,
          excludeSemantics: true,
          onTap: _toggleValue,
          child: InkWell(
            excludeFromSemantics: true,
            onTap: _toggleValue,
            borderRadius: BorderRadius.circular(VSPRadius.md),
            child: SizedBox(
              width: VSPSize.touchTarget,
              height: VSPSize.touchTarget,
              child: Center(
                child: AnimatedContainer(
                  duration: VSPDSMotion.navigationSwitch,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: value ? VSPColors.accent : VSPColors.surface,
                    borderRadius: BorderRadius.circular(VSPRadius.sm),
                    border: Border.all(
                      color: value ? VSPColors.accent : VSPColors.borderLight,
                      width: 1.5,
                    ),
                  ),
                  child: value
                      ? const Icon(
                          Iconsax.tick_circle_copy,
                          size: 16,
                          color: VSPColors.black,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: _toggleValue,
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
                    recognizer: _termsRecognizer,
                    style: const TextStyle(
                      color: VSPColors.accent,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  TextSpan(text: l10n.and),
                  TextSpan(
                    text: l10n.privacyPolicy,
                    recognizer: _privacyRecognizer,
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
    );
  }
}
