import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../shared/widgets/vsp_empty_state.dart';

class OwnerCupEmptyView extends StatelessWidget {
  final int selectedTab;
  final bool hasAnyChampionships;
  final String createFirstText;
  final VoidCallback onOpenFormatSheet;

  const OwnerCupEmptyView({
    super.key,
    required this.selectedTab,
    required this.hasAnyChampionships,
    required this.createFirstText,
    required this.onOpenFormatSheet,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final String emptyTitle;
    final String emptySubtitle;

    if (selectedTab == 0) {
      emptyTitle = isArabic ? 'لا توجد بطولات قادمة' : 'No upcoming tournaments';
      emptySubtitle = isArabic ? 'قم بإنشاء بطولة جديدة لتظهر هنا' : 'Create a tournament to show it here';
    } else if (selectedTab == 1) {
      emptyTitle = isArabic ? 'لا توجد بطولات جارية حالياً' : 'No ongoing tournaments currently';
      emptySubtitle = isArabic ? 'البطولات المبدوءة والمستمرة ستظهر هنا' : 'Active ongoing tournaments will appear here';
    } else {
      emptyTitle = isArabic ? 'لا توجد بطولات منتهية بعد' : 'No finished tournaments yet';
      emptySubtitle = isArabic ? 'البطولات المكتملة ستظهر في هذا الأرشيف' : 'Completed tournaments will be archived here';
    }

    return VSPEmptyState(
      icon: Iconsax.cup_copy,
      title: emptyTitle,
      subtitle: emptySubtitle,
      buttonText: hasAnyChampionships ? null : createFirstText,
      onButtonPressed: hasAnyChampionships ? null : onOpenFormatSheet,
    );
  }
}
