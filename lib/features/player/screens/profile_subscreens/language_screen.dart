import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/providers/language_provider.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    final languages = [
      {'name': 'English', 'code': 'en'},
      {'name': 'Ø§Ù„Ø¹Ø±Ø¨ÙŠØ©', 'code': 'ar'},
    ];

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, matchTextDirection: true, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.language,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...languages.map((lang) => _buildLanguageItem(
              context, 
              lang['name']!, 
              lang['code']!, 
              languageProvider.currentLanguage == lang['code'],
              (code) => languageProvider.changeLanguage(code),
            )),
            
            const Spacer(),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSPColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                ),
                child: Text(
                  AppLocalizations.of(context)!.done, 
                  style: const TextStyle(color: VSPColors.background, fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageItem(BuildContext context, String name, String code, bool isSelected, Function(String) onSelect) {
    return GestureDetector(
      onTap: () => onSelect(code),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: isSelected ? Border.all(color: VSPColors.accent) : Border.all(color: VSPColors.divider.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: Theme.of(context).textTheme.bodyLarge),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? VSPColors.accent : VSPColors.divider, width: 2),
              ),
              child: isSelected ? Center(child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: VSPColors.accent, shape: BoxShape.circle))) : null,
            )
          ],
        ),
      ),
    );
  }
}

