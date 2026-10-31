import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../../core/ui/vsp_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../shared/widgets/vsp_back_button.dart';

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
      {'name': 'العربية', 'code': 'ar'},
    ];

    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const VSPBackButton(),
        title: Text(
          AppLocalizations.of(context)!.language,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
              child: Column(
                children: [
                  ...languages.map((lang) => _buildLanguageItem(
                    context,
                    lang['name']!,
                    lang['code']!,
                    languageProvider.currentLanguage == lang['code'],
                    (code) {
                      HapticFeedback.lightImpact();
                      languageProvider.changeLanguage(code);
                    },
                  )),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VSPColors.accent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.done,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageItem(
    BuildContext context,
    String name,
    String code,
    bool isSelected,
    ValueChanged<String> onSelect,
  ) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: name,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelect(code),
          borderRadius: BorderRadius.circular(VSPRadius.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(
                color: isSelected
                    ? VSPColors.accent
                    : VSPColors.divider.withValues(alpha: 0.3),
              ),
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
                    border: Border.all(
                      color: isSelected ? VSPColors.accent : VSPColors.divider,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: VSPColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

