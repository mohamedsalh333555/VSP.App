import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_design_tokens.dart';
import '../../../../shared/widgets/vsp_empty_state.dart';

class ChampionEmptyState extends StatelessWidget {
  final IconData icon;
  final String titleArabic;
  final String titleEnglish;
  final String descriptionArabic;
  final String descriptionEnglish;
  final bool? isArabic;

  const ChampionEmptyState({
    super.key,
    required this.icon,
    required this.titleArabic,
    required this.titleEnglish,
    required this.descriptionArabic,
    required this.descriptionEnglish,
    this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final useArabic = isArabic ??
        Localizations.localeOf(context).languageCode == 'ar';
    return VSPEmptyState(
      icon: icon,
      title: useArabic ? titleArabic : titleEnglish,
      subtitle: useArabic ? descriptionArabic : descriptionEnglish,
    );
  }
}

class ChampionshipsEmptyState extends StatelessWidget {
  final String locationName;
  final bool showReturnButton;
  final VoidCallback? onReturn;

  const ChampionshipsEmptyState({
    super.key,
    required this.locationName,
    this.showReturnButton = false,
    this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      children: [
        Expanded(
          child: ChampionEmptyState(
            icon: Iconsax.cup_copy,
            titleArabic: 'لا توجد بطولات حالياً',
            titleEnglish: 'No tournaments available',
            descriptionArabic:
                'لا توجد بطولات متاحة حالياً في $locationName. ستظهر هنا البطولات الجديدة عند توفرها.',
            descriptionEnglish:
                'There are no tournaments available in $locationName right now. New tournaments will appear here when available.',
          ),
        ),
        if (showReturnButton && onReturn != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: VSPDSSpacing.md,
              end: VSPDSSpacing.md,
              bottom: VSPDSSpacing.md,
            ),
            child: TextButton(
              onPressed: onReturn,
              child: Text(
                isArabic ? 'العودة لمحافظتي' : 'Return to my location',
                style: VSPDSTypography.actionLabel,
              ),
            ),
          ),
      ],
    );
  }
}

class TeamsEmptyState extends StatelessWidget {
  const TeamsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChampionEmptyState(
      icon: Iconsax.people_copy,
      titleArabic: 'لا توجد فرق حالياً',
      titleEnglish: 'No teams available',
      descriptionArabic:
          'لا توجد فرق مسجلة ضمن النطاق المحدد حالياً. ستظهر الفرق هنا عند توفرها.',
      descriptionEnglish:
          'There are no teams in the selected area right now. Teams will appear here when available.',
    );
  }
}

class OneVsOneEmptyState extends StatelessWidget {
  final String locationName;

  const OneVsOneEmptyState({super.key, required this.locationName});

  @override
  Widget build(BuildContext context) {
    return ChampionEmptyState(
      icon: Iconsax.user_copy,
      titleArabic: 'لا توجد بطولة واحد ضد واحد حالياً',
      titleEnglish: 'No active 1vs1 tournament',
      descriptionArabic:
          'لا توجد بطولة واحد ضد واحد نشطة حالياً في $locationName. ترقب إعلان البطولة القادمة.',
      descriptionEnglish:
          'There is no active 1vs1 tournament in $locationName right now. Stay tuned for the next tournament.',
    );
  }
}
