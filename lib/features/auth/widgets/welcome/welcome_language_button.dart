import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import 'scale_animated_button.dart';

/// Glassmorphic language toggle button with backdrop blur.
class WelcomeLanguageButton extends StatelessWidget {
  const WelcomeLanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, langProvider, _) {
        return ScaleAnimatedButton(
          onPressed: () {
            langProvider.changeLanguage(langProvider.isArabic ? 'en' : 'ar');
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(VSPRadius.full),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: VSPColors.glassSurface,
                  borderRadius: BorderRadius.circular(VSPRadius.full),
                  border: Border.all(color: VSPColors.glassBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.global_copy, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      langProvider.isArabic
                          ? AppLocalizations.of(context)!.english
                          : AppLocalizations.of(context)!.arabic,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
